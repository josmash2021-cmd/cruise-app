/// Google Maps JSON styling for light and dark themes.
/// Usage: `mapCtrl.setMapStyle(isDark ? MapStyles.dark : MapStyles.light);`
class MapStyles {
  MapStyles._();

  // ═════════════════════════════════════════════════════
  //  DARK — Dark theme with golden roads (Cruise brand)
  // ═════════════════════════════════════════════════════
  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1a1a2e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a8a9e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d4a843"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#1e1e32"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#222238"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#9e9e7a"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1a2e1e"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#5a8a5e"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#3d3520"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#c8b87a"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#352e1c"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#4a3f24"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#6b5a28"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#2a2410"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#e8c547"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry.fill","stylers":[{"color":"#7a6830"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#222238"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#c8a84a"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1a2e"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3a4a6a"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#0e1a2e"}]}
]
''';

  // ═════════════════════════════════════════════════════
  //  LIGHT — Clean white with golden highway accents
  // ═════════════════════════════════════════════════════
  static const light = '''
[
  {"elementType":"geometry","stylers":[{"color":"#F0F0F5"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6E6E73"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#D1D1D6"},{"visibility":"simplified"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#C7C7CC"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#EBEBF0"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#E8E8ED"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#E5E5EA"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#C8E6C5"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#D6D6DB"},{"weight":0.5}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8E8E93"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#FFF0C8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#E8D8A0"},{"weight":0.5}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#8a7540"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry.fill","stylers":[{"color":"#FFE8A0"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E5E5EA"}]},
  {"featureType":"transit.station","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#A8D4E6"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#7FBBD4"}]}
]
''';

  // ═════════════════════════════════════════════════════
  //  NAVIGATION — Ultra-dark with golden route highlights
  // ═════════════════════════════════════════════════════
  static const navigation = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1a1a2e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#5a5a7a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#8888aa"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#16162b"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#1e1e38"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1e1e38"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1a2e1a"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#3d3520"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#141428"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#c8b87a"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#302a18"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#3a3220"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#5a4e24"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1a1a30"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#d4a843"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1e1e38"}]},
  {"featureType":"transit.station","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1a2e"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3a4a6a"}]}
]
''';
}
