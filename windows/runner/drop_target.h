#ifndef RUNNER_DROP_TARGET_H_
#define RUNNER_DROP_TARGET_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// 接收从软件外部拖进来的内容，转发给 Dart 处理。
//
// 用 OLE 的 IDropTarget 而不是旧的 WM_DROPFILES：后者只认文件路径，
// 而从网页或别的文档里拖一段选中的文字过来时，数据是 CF_UNICODETEXT，
// 只有 IDropTarget 拿得到。
void RegisterExternalDropTarget(HWND hwnd, flutter::BinaryMessenger* messenger);

// 撤销注册。窗口销毁前调用，否则 OLE 会握着一个悬空的指针。
void UnregisterExternalDropTarget(HWND hwnd);

#endif  // RUNNER_DROP_TARGET_H_
