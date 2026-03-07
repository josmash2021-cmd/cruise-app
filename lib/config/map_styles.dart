/// Google Maps JSON styling for light and dark themes.
/// Usage: `mapCtrl.setMapStyle(isDark ? MapStyles.dark : MapStyles.light);`
class MapStyles {
  MapStyles._();

  // ═════════════════════════════════════════════════════
  //  DARK — Grey theme with golden roads (Cruise brand)
  // ═════════════════════════════════════════════════════
  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#2c2c2c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#999999"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#e8c547"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#303030"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#353535"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#888878"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#2a372a"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#5a8a5e"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#b8982e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#d4b84a"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#9a7e28"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#c4a432"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#e8c547"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#e8c547"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry.fill","stylers":[{"color":"#f0d060"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#353535"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d4a843"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#1a1a1a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a4a4a"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#1a1a1a"}]}
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
  //  NAVIGATION — Grey with golden route highlights
  // ═════════════════════════════════════════════════════
  static const navigation = '''
[
  {"elementType":"geometry","stylers":[{"color":"#2c2c2c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#707070"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#999999"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#282828"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#303030"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#303030"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#2a372a"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#b8982e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#242424"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#d4b84a"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#8a7224"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#a8902a"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#e8c547"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#e8c547"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#303030"}]},
  {"featureType":"transit.station","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#1a1a1a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a4a4a"}]}
]
''';
}
