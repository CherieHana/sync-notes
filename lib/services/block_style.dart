import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// 正文里内嵌块（图片、手写画布）的大小与旋转。
///
/// 这两个值当成 Quill 的块属性存在正文里，跟着笔记一起同步，不用改数据库。
/// `width` 是 flutter_quill 已经注册过的属性；`rotate` 是我们自己加的键，
/// Quill 解析不认识的字时会按 `ignore` 作用域原样留着（见 `Style.fromJson`
/// 的兜底分支），所以也能安全往返。作用域用 `ignore`：它不参与行内排版规则，
/// 打字时也不会被"继承"到后面的文字上。
const String blockWidthKey = 'width';
const String blockRotateKey = 'rotate';

/// 块宽度的可调范围，逻辑像素。
const double minBlockWidth = 80;
const double maxBlockWidth = 600;

/// 一个内嵌块在正文里怎么显示。缺省就是「按原比例自动尺寸、不旋转」。
class BlockStyle {
  const BlockStyle({this.width, this.rotate});

  /// 显示宽度（逻辑像素）。null 表示按原始比例自动算。
  final double? width;

  /// 旋转角度（度，0~360）。null / 0 表示不转。
  final double? rotate;

  static const BlockStyle none = BlockStyle();

  /// 是不是「什么都没设」，也就是老笔记里那些块的样子。
  bool get isDefault => width == null && (rotate == null || rotate == 0);

  /// 从内嵌块的属性里读出来。
  static BlockStyle fromAttributes(Map<String, Attribute> attributes) {
    if (attributes.isEmpty) return none;
    return BlockStyle(
      width: _clampWidth(_asDouble(attributes[blockWidthKey]?.value)),
      rotate: _normalizeAngle(_asDouble(attributes[blockRotateKey]?.value)),
    );
  }

  /// 从正文 JSON 里的原始属性表读出来（导出长图走这条路）。
  static BlockStyle fromJson(Map<dynamic, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) return none;
    return BlockStyle(
      width: _clampWidth(_asDouble(attributes[blockWidthKey])),
      rotate: _normalizeAngle(_asDouble(attributes[blockRotateKey])),
    );
  }

  BlockStyle copyWith({double? width, double? rotate}) =>
      BlockStyle(width: width ?? this.width, rotate: rotate ?? this.rotate);

  @override
  bool operator ==(Object other) =>
      other is BlockStyle && other.width == width && other.rotate == rotate;

  @override
  int get hashCode => Object.hash(width, rotate);

  @override
  String toString() => 'BlockStyle(width: $width, rotate: $rotate)';
}

/// 排版结果：外层要占多大、内容本身多大、转了多少弧度。
class BlockLayout {
  const BlockLayout({
    required this.box,
    required this.content,
    required this.angle,
  });

  /// 在正文里占据的尺寸（旋转之后的外接矩形），行高按它算。
  final Size box;

  /// 内容本身的尺寸（旋转之前）。
  final Size content;

  /// 旋转弧度，正数顺时针。
  final double angle;

  bool get isRotated => angle.abs() > 0.0001;
}

/// 按原始宽高比算「自动尺寸」——不设宽度时就用它。
///
/// 这段逻辑原来分别写在图片和手写两个渲染器里，抽出来是为了让正文和导出长图
/// 用的是同一套算法，不会两边长得不一样。
Size autoBlockSize({
  required double aspectRatio,
  double maxWidth = 300,
  double maxHeight = 240,
  double minWidth = 0,
}) {
  final ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 4 / 3;
  var width = maxWidth;
  var height = width / ratio;
  if (height > maxHeight) {
    height = maxHeight;
    width = height * ratio;
  }
  if (width < minWidth) {
    width = minWidth;
    height = width / ratio;
  }
  return Size(width, height);
}

/// 结合大小/旋转，算出真正要渲染的排版尺寸。
///
/// 旋转之后内容会超出原来的框，这里按外接矩形给外层尺寸——行高才会跟着变，
/// 不然转过的块会压住上下两行文字。
BlockLayout layoutBlock({
  required Size autoSize,
  BlockStyle style = BlockStyle.none,
}) {
  final baseRatio = autoSize.width <= 0
      ? 1.0
      : autoSize.height / autoSize.width;
  final width = _clampWidth(style.width) ?? autoSize.width;
  final content = Size(width, width * baseRatio);

  final radians = (style.rotate ?? 0) * math.pi / 180;
  final cos = math.cos(radians).abs();
  final sin = math.sin(radians).abs();
  // 0 度时这里要精确等于 content，不然老笔记的排版会跟着抖。
  if (radians == 0) {
    return BlockLayout(box: content, content: content, angle: 0);
  }

  final box = Size(
    content.width * cos + content.height * sin,
    content.width * sin + content.height * cos,
  );
  return BlockLayout(box: box, content: content, angle: radians);
}

/// 把大小/旋转写进正文里第 [offset] 个位置的那个内嵌块。
///
/// 传 null 的属性会被清掉（回到自动尺寸 / 不旋转）。这里直接 compose 一个
/// retain 增量，不走格式化规则：我们的键是 `ignore` 作用域，规则链里没有
/// 认它的规则，走 format() 会直接抛异常。
void applyBlockStyle(Document document, int offset, BlockStyle style) {
  final attributes = <String, dynamic>{
    blockWidthKey: _clampWidth(style.width),
    blockRotateKey: _normalizeAngle(style.rotate),
  };
  document.compose(
    Delta()
      ..retain(offset)
      ..retain(1, attributes),
    ChangeSource.local,
  );
}

/// 正文里的字号档位 → 具体像素值。编辑器和导出长图共用同一套映射。
double inlineFontSizeFor(Object? value) => switch (value) {
  'small' => 12,
  'large' => 22,
  'huge' => 32,
  _ => 16,
};

/// 把 `#AARRGGBB` 这样的颜色值解析出来（Quill 的颜色属性就是这个格式）。
Color? parseAttributeColor(Object? value) {
  if (value is! String) return null;
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'ff$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

double? _asDouble(Object? value) => switch (value) {
  null => null,
  num number => number.toDouble(),
  String text => double.tryParse(text),
  _ => null,
};

double? _clampWidth(double? width) {
  if (width == null || !width.isFinite) return null;
  return width.clamp(minBlockWidth, maxBlockWidth).toDouble();
}

/// 角度归一到 [0, 360)。0 度统一成 null，省得正文里留一堆没用的属性。
double? _normalizeAngle(double? degrees) {
  if (degrees == null || !degrees.isFinite) return null;
  var value = degrees % 360;
  if (value < 0) value += 360;
  if (value.abs() < 0.001 || (value - 360).abs() < 0.001) return null;
  return value;
}
