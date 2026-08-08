import 'dart:convert';
import 'package:isar/isar.dart';
import '../models/macro_model.dart';
import '../../domain/entities/macro_entity.dart';

class MacroRepository {
  final Future<Isar> _isarFuture;

  MacroRepository(this._isarFuture);

  Future<List<MacroEntity>> getAll() async {
    var isar = await _isarFuture;
    var models = await isar.macroModels.where().findAll();
    return models.map(_toEntity).toList();
  }

  Future<MacroEntity?> getById(int id) async {
    var isar = await _isarFuture;
    var model = await isar.macroModels.get(id);
    return model != null ? _toEntity(model) : null;
  }

  Future<int> save(MacroEntity macro) async {
    var isar = await _isarFuture;
    var model = _toModel(macro);
    return await isar.writeTxn(() => isar.macroModels.put(model));
  }

  Future<void> delete(int id) async {
    var isar = await _isarFuture;
    await isar.writeTxn(() => isar.macroModels.delete(id));
  }

  MacroEntity _toEntity(MacroModel m) {
    List<dynamic> jsonList = jsonDecode(m.actionsJson);
    return MacroEntity(
      id: m.id,
      name: m.name,
      actions: jsonList.map((j) => MacroAction.fromJson(j)).toList(),
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  MacroModel _toModel(MacroEntity e) {
    return MacroModel()
      ..id = e.id == 0 ? Isar.autoIncrement : e.id
      ..name = e.name
      ..actionsJson = jsonEncode(e.actions.map((a) => a.toJson()).toList())
      ..createdAt = e.createdAt
      ..updatedAt = e.updatedAt;
  }
}
