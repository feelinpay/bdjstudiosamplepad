import '../../../../core/audio/trigger_mode.dart';

enum PadState { idle, playing, queued }

enum PadType { audio, folder, macro }

class PadEntity {
  final String id;
  final int index;
  final PadType type;
  final int? targetPageIndex;
  final int? targetMacroId;
  final String? sampleId;
  final int colorHex;
  final String label;
  final PadState state;
  final TriggerMode playMode;
  final int chokeGroup;
  final double pan;
  final double pitch;
  final double volume;
  final bool isProtected;
  final bool reverse;
  final Duration fadeIn;
  final Duration fadeOut;
  final Duration startPoint;
  final Duration? endPoint;
  final Duration loopPoint;
  final String? backgroundImagePath;

  const PadEntity({
    required this.id,
    required this.index,
    this.type = PadType.audio,
    this.targetPageIndex,
    this.targetMacroId,
    this.sampleId,
    this.colorHex = 0xFF424242,
    this.label = '',
    this.state = PadState.idle,
    this.playMode = TriggerMode.oneShot,
    this.chokeGroup = 0,
    this.pan = 0.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.isProtected = false,
    this.reverse = false,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.startPoint = Duration.zero,
    this.endPoint,
    this.loopPoint = Duration.zero,
    this.backgroundImagePath,
  });

  /// Conveniencia: true si el pad es una carpeta.
  bool get isFolder => type == PadType.folder;

  /// Conveniencia: true si el pad es una macro.
  bool get isMacro => type == PadType.macro;

  factory PadEntity.empty(int index) {
    return PadEntity(id: 'pad_$index', index: index, label: 'PAD ${index + 1}');
  }

  PadEntity copyWith({
    String? id,
    int? index,
    PadType? type,
    int? targetPageIndex,
    int? targetMacroId,
    String? sampleId,
    int? colorHex,
    String? label,
    PadState? state,
    TriggerMode? playMode,
    int? chokeGroup,
    double? pan,
    double? pitch,
    double? volume,
    bool? isProtected,
    bool? reverse,
    Duration? fadeIn,
    Duration? fadeOut,
    Duration? startPoint,
    Duration? endPoint,
    Duration? loopPoint,
    String? backgroundImagePath,
  }) {
    return PadEntity(
      id: id ?? this.id,
      index: index ?? this.index,
      type: type ?? this.type,
      targetPageIndex: targetPageIndex ?? this.targetPageIndex,
      targetMacroId: targetMacroId ?? this.targetMacroId,
      sampleId: sampleId ?? this.sampleId,
      colorHex: colorHex ?? this.colorHex,
      label: label ?? this.label,
      state: state ?? this.state,
      playMode: playMode ?? this.playMode,
      chokeGroup: chokeGroup ?? this.chokeGroup,
      pan: pan ?? this.pan,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      isProtected: isProtected ?? this.isProtected,
      reverse: reverse ?? this.reverse,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      loopPoint: loopPoint ?? this.loopPoint,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PadEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          index == other.index &&
          type == other.type &&
          targetPageIndex == other.targetPageIndex &&
          targetMacroId == other.targetMacroId &&
          sampleId == other.sampleId &&
          colorHex == other.colorHex &&
          label == other.label &&
          state == other.state &&
          playMode == other.playMode &&
          pan == other.pan &&
          pitch == other.pitch &&
          volume == other.volume &&
          isProtected == other.isProtected &&
          reverse == other.reverse &&
          fadeIn == other.fadeIn &&
          fadeOut == other.fadeOut &&
          startPoint == other.startPoint &&
          endPoint == other.endPoint &&
          loopPoint == other.loopPoint &&
          backgroundImagePath == other.backgroundImagePath;

  @override
  int get hashCode =>
      id.hashCode ^
      index.hashCode ^
      type.hashCode ^
      targetPageIndex.hashCode ^
      targetMacroId.hashCode ^
      sampleId.hashCode ^
      colorHex.hashCode ^
      label.hashCode ^
      state.hashCode ^
      playMode.hashCode ^
      pan.hashCode ^
      pitch.hashCode ^
      volume.hashCode ^
      isProtected.hashCode ^
      reverse.hashCode ^
      fadeIn.hashCode ^
      fadeOut.hashCode ^
      startPoint.hashCode ^
      endPoint.hashCode ^
      loopPoint.hashCode ^
      backgroundImagePath.hashCode;
}
