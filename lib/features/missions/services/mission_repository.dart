import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/mission_plan.dart';

/// Device-local storage. No cloud sync or encryption is claimed.
class MissionRepository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'sarisa_mission_plans.json'));
  }

  Future<List<MissionPlan>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    return MissionPlan.decodeAll(await file.readAsString());
  }

  Future<void> save(List<MissionPlan> missions) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(MissionPlan.encodeAll(missions), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
