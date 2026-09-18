#include "drop_target.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <ole2.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

namespace {

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int length = static_cast<int>(value.size());
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, value.c_str(), length,
                                         nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string result(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, value.c_str(), length, result.data(), size,
                        nullptr, nullptr);
  return result;
}

std::vector<std::wstring> ReadFileList(IDataObject* data) {
  std::vector<std::wstring> paths;
  FORMATETC format = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM medium{};
  if (FAILED(data->GetData(&format, &medium))) {
    return paths;
  }
  if (medium.hGlobal != nullptr) {
    auto hdrop = static_cast<HDROP>(::GlobalLock(medium.hGlobal));
    if (hdrop != nullptr) {
      const UINT count = ::DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < count; ++i) {
        const UINT length = ::DragQueryFileW(hdrop, i, nullptr, 0);
        if (length == 0) {
          continue;
        }
        std::wstring path(static_cast<size_t>(length) + 1, L'\0');
        if (::DragQueryFileW(hdrop, i, path.data(), length + 1) != 0) {
          path.resize(length);
          paths.push_back(path);
        }
      }
      ::GlobalUnlock(medium.hGlobal);
    }
  }
  ::ReleaseStgMedium(&medium);
  return paths;
}

std::wstring ReadText(IDataObject* data) {
  FORMATETC format = {CF_UNICODETEXT, nullptr, DVASPECT_CONTENT, -1,
                      TYMED_HGLOBAL};
  STGMEDIUM medium{};
  if (FAILED(data->GetData(&format, &medium))) {
    return std::wstring();
  }
  std::wstring text;
  if (medium.hGlobal != nullptr) {
    const auto* raw = static_cast<const wchar_t*>(::GlobalLock(medium.hGlobal));
    if (raw != nullptr) {
      text.assign(raw);
      ::GlobalUnlock(medium.hGlobal);
    }
  }
  ::ReleaseStgMedium(&medium);
  return text;
}

bool HasUsableContent(IDataObject* data) {
  if (data == nullptr) {
    return false;
  }
  FORMATETC format = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  if (data->QueryGetData(&format) == S_OK) {
    return true;
  }
  format.cfFormat = CF_UNICODETEXT;
  return data->QueryGetData(&format) == S_OK;
}

class DropTargetImpl : public IDropTarget {
 public:
  explicit DropTargetImpl(flutter::BinaryMessenger* messenger)
      : channel_(
            std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "sync_notes/drop",
                &flutter::StandardMethodCodec::GetInstance())) {}

  DropTargetImpl(const DropTargetImpl&) = delete;
  DropTargetImpl& operator=(const DropTargetImpl&) = delete;

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           void** object) override {
    if (object == nullptr) {
      return E_INVALIDARG;
    }
    if (riid == IID_IUnknown || riid == IID_IDropTarget) {
      *object = static_cast<IDropTarget*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override {
    return static_cast<ULONG>(::InterlockedIncrement(&ref_count_));
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const LONG count = ::InterlockedDecrement(&ref_count_);
    if (count == 0) {
      delete this;
    }
    return static_cast<ULONG>(count);
  }

  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data, DWORD, POINTL,
                                      DWORD* effect) override {
    acceptable_ = HasUsableContent(data);
    if (effect != nullptr) {
      *effect = acceptable_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragOver(DWORD, POINTL, DWORD* effect) override {
    if (effect != nullptr) {
      *effect = acceptable_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragLeave() override {
    acceptable_ = false;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data, DWORD, POINTL,
                                 DWORD* effect) override {
    acceptable_ = false;
    if (effect != nullptr) {
      *effect = DROPEFFECT_COPY;
    }
    if (data == nullptr) {
      return S_OK;
    }

    const std::vector<std::wstring> paths = ReadFileList(data);
    const std::wstring text = ReadText(data);
    if (paths.empty() && text.empty()) {
      return S_OK;
    }

    flutter::EncodableList files;
    for (const auto& path : paths) {
      files.push_back(flutter::EncodableValue(WideToUtf8(path)));
    }
    flutter::EncodableMap payload;
    payload[flutter::EncodableValue("files")] =
        flutter::EncodableValue(files);
    if (!text.empty()) {
      payload[flutter::EncodableValue("text")] =
          flutter::EncodableValue(WideToUtf8(text));
    }

    channel_->InvokeMethod(
        "dropped",
        std::make_unique<flutter::EncodableValue>(payload), nullptr);
    return S_OK;
  }

 private:
  ~DropTargetImpl() = default;

  LONG ref_count_ = 1;
  bool acceptable_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void RegisterExternalDropTarget(HWND hwnd,
                                flutter::BinaryMessenger* messenger) {
  // RegisterDragDrop 要求线程已经初始化 OLE；重复调用是安全的。
  ::OleInitialize(nullptr);

  auto* target = new DropTargetImpl(messenger);
  if (SUCCEEDED(::RegisterDragDrop(hwnd, target))) {
    // 注册成功后 OLE 自己也加了一次引用，把我们这份放掉，
    // 之后由 RevokeDragDrop 触发析构。
    target->Release();
  } else {
    target->Release();
  }
}

void UnregisterExternalDropTarget(HWND hwnd) {
  ::RevokeDragDrop(hwnd);
}
