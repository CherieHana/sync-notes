#ifndef RUNNER_CLIPBOARD_IMAGE_CHANNEL_H_
#define RUNNER_CLIPBOARD_IMAGE_CHANNEL_H_

#include <flutter/binary_messenger.h>

// 注册读取系统剪切板里图片的平台通道。
//
// Dart 那边看到的是名为 sync_notes/clipboard_image 的 MethodChannel，
// 只有一个 readImage 方法：剪切板里有图片就返回像素或文件字节，
// 没有就返回 null。
//
// 之所以自己写而不是引第三方包：能读剪切板图片的 Flutter 包要么需要
// Rust 工具链编译，要么多年没维护，为这一个功能引入构建依赖不划算。
void RegisterClipboardImageChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_CLIPBOARD_IMAGE_CHANNEL_H_
