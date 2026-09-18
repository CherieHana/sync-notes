#include "clipboard_image_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <memory>
#include <optional>
#include <vector>

namespace {

// 把剪切板里的 DIB 位图转成自上而下的 RGBA 像素。
//
// 只处理最常见的 24/32 位无压缩位图——截图工具和浏览器贴进来的基本都长这样。
// 别的格式（带压缩、带调色板的）直接放弃，让上层走「没有图片」的分支。
bool ConvertDibToRgba(const BITMAPINFOHEADER& header, const uint8_t* bits,
                      size_t available, int32_t* width, int32_t* height,
                      std::vector<uint8_t>* out) {
  if (bits == nullptr || width == nullptr || height == nullptr ||
      out == nullptr) {
    return false;
  }
  if (header.biSize < sizeof(BITMAPINFOHEADER)) {
    return false;
  }

  const int32_t w = header.biWidth;
  // biHeight 为正表示自下而上存，为负表示自上而下。
  const bool bottom_up = header.biHeight > 0;
  const int32_t h = bottom_up ? header.biHeight : -header.biHeight;
  if (w <= 0 || h <= 0) {
    return false;
  }

  const uint16_t depth = static_cast<uint16_t>(header.biBitCount);
  if (depth != 24 && depth != 32) {
    return false;
  }
  if (header.biCompression != BI_RGB && header.biCompression != BI_BITFIELDS) {
    return false;
  }
  if (header.biCompression == BI_BITFIELDS && depth != 32) {
    return false;
  }

  const size_t bytes_per_pixel = depth / 8;
  // 每行都按 4 字节对齐。
  const size_t src_stride =
      ((static_cast<size_t>(w) * bytes_per_pixel + 3) / 4) * 4;
  const size_t needed = src_stride * static_cast<size_t>(h);
  if (available < needed) {
    return false;
  }

  out->assign(static_cast<size_t>(w) * static_cast<size_t>(h) * 4, 0xFF);
  for (int32_t y = 0; y < h; ++y) {
    const int32_t src_row = bottom_up ? (h - 1 - y) : y;
    const uint8_t* src = bits + src_stride * static_cast<size_t>(src_row);
    uint8_t* dst =
        out->data() + static_cast<size_t>(w) * 4 * static_cast<size_t>(y);
    for (int32_t x = 0; x < w; ++x) {
      const uint8_t* px = src + static_cast<size_t>(x) * bytes_per_pixel;
      // DIB 里是 BGRA 顺序，Dart 那边按 RGBA 解析，这里换过来。
      dst[0] = px[2];
      dst[1] = px[1];
      dst[2] = px[0];
      dst[3] = static_cast<uint8_t>(depth == 32 ? px[3] : 0xFF);
      dst += 4;
    }
  }

  *width = w;
  *height = h;
  return true;
}

std::optional<flutter::EncodableMap> MakeFileResult(
    const uint8_t* data, size_t size) {
  if (data == nullptr || size == 0) {
    return std::nullopt;
  }
  std::vector<uint8_t> bytes(data, data + size);
  flutter::EncodableMap map;
  map[flutter::EncodableValue("format")] = flutter::EncodableValue("file");
  map[flutter::EncodableValue("bytes")] = flutter::EncodableValue(bytes);
  return map;
}

std::optional<flutter::EncodableMap> ReadPngFormat() {
  const UINT format = ::RegisterClipboardFormatW(L"PNG");
  if (format == 0 || !::IsClipboardFormatAvailable(format)) {
    return std::nullopt;
  }
  HANDLE handle = ::GetClipboardData(format);
  if (handle == nullptr) {
    return std::nullopt;
  }
  const auto* data = static_cast<const uint8_t*>(::GlobalLock(handle));
  if (data == nullptr) {
    return std::nullopt;
  }
  const auto result = MakeFileResult(data, ::GlobalSize(handle));
  ::GlobalUnlock(handle);
  return result;
}

std::optional<flutter::EncodableMap> ReadDibFormat() {
  if (!::IsClipboardFormatAvailable(CF_DIB)) {
    return std::nullopt;
  }
  HANDLE handle = ::GetClipboardData(CF_DIB);
  if (handle == nullptr) {
    return std::nullopt;
  }
  const auto* base = static_cast<const uint8_t*>(::GlobalLock(handle));
  if (base == nullptr) {
    return std::nullopt;
  }

  std::optional<flutter::EncodableMap> result;
  const size_t total = ::GlobalSize(handle);
  if (total >= sizeof(BITMAPINFOHEADER)) {
    BITMAPINFOHEADER header{};
    std::memcpy(&header, base, sizeof(BITMAPINFOHEADER));

    // 位图数据跟在头后面；BI_BITFIELDS 还要多跳 3 个掩码。
    size_t offset = sizeof(BITMAPINFOHEADER);
    if (header.biCompression == BI_BITFIELDS) {
      offset += 3 * sizeof(DWORD);
    }

    if (total > offset) {
      std::vector<uint8_t> pixels;
      int32_t width = 0;
      int32_t height = 0;
      if (ConvertDibToRgba(header, base + offset, total - offset, &width,
                           &height, &pixels)) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("format")] = flutter::EncodableValue("rgba");
        map[flutter::EncodableValue("bytes")] =
            flutter::EncodableValue(pixels);
        map[flutter::EncodableValue("width")] =
            flutter::EncodableValue(width);
        map[flutter::EncodableValue("height")] =
            flutter::EncodableValue(height);
        result = map;
      }
    }
  }

  ::GlobalUnlock(handle);
  return result;
}

std::optional<flutter::EncodableMap> ReadClipboardImage() {
  if (!::OpenClipboard(nullptr)) {
    return std::nullopt;
  }

  // 优先找 PNG：有些程序直接放的就是图片文件字节，不需要我们转像素。
  auto result = ReadPngFormat();
  if (!result.has_value()) {
    result = ReadDibFormat();
  }

  ::CloseClipboard();
  return result;
}

}  // namespace

void RegisterClipboardImageChannel(flutter::BinaryMessenger* messenger) {
  // 通道要在整个进程生命周期内存活，所以用静态变量持有。
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      channel;
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "sync_notes/clipboard_image",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "readImage") {
          result->NotImplemented();
          return;
        }
        const auto image = ReadClipboardImage();
        if (!image.has_value()) {
          // 剪切板里没有图片。返回空值，Dart 那边当作「没什么可粘的」。
          result->Success();
          return;
        }
        result->Success(flutter::EncodableValue(image.value()));
      });
}
