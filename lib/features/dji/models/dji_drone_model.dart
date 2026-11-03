class DjiDroneModel {
  final String id;
  final String name;
  final String category;

  const DjiDroneModel({
    required this.id,
    required this.name,
    required this.category,
  });

  static const catalog = <DjiDroneModel>[
    DjiDroneModel(id: 'mini4pro', name: 'DJI Mini 4 Pro', category: 'Compact'),
    DjiDroneModel(id: 'mavic3e', name: 'DJI Mavic 3 Enterprise', category: 'Enterprise'),
    DjiDroneModel(id: 'matrice30', name: 'DJI Matrice 30', category: 'Enterprise'),
    DjiDroneModel(id: 'matrice350', name: 'DJI Matrice 350 RTK', category: 'Industrial'),
    DjiDroneModel(id: 'matrice4', name: 'DJI Matrice 4', category: 'Enterprise'),
  ];
}
