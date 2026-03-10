import 'package:flutter/material.dart';

/// Configuración global de responsividad para todas las pantallas
class AppResponsiveConfig {
  /// Tamaños de pantalla estándar
  static const double smallScreenWidth = 360;
  static const double mediumScreenWidth = 400;
  static const double largeScreenWidth = 480;
  
  /// Obtiene el factor de escala basado en el ancho de pantalla
  static double getScaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < smallScreenWidth) {
      return 0.9; // Pantallas pequeñas: reducir 10%
    } else if (width > largeScreenWidth) {
      return 1.1; // Pantallas grandes: aumentar 10%
    }
    
    return 1.0; // Pantallas medianas: tamaño normal
  }
  
  /// Padding horizontal adaptativo
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < smallScreenWidth) {
      return 16;
    } else if (width > largeScreenWidth) {
      return 32;
    }
    
    return 24;
  }
  
  /// Tamaño de fuente adaptativo
  static double fontSize(BuildContext context, double baseSize) {
    return baseSize * getScaleFactor(context);
  }
  
  /// Padding inferior considerando teclado y safe area
  static double bottomPadding(BuildContext context, {double base = 16}) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    // Si el teclado está visible, usar solo padding base
    if (keyboardHeight > 0) {
      return base;
    }
    
    // Si no hay teclado, agregar safe area
    return mediaQuery.padding.bottom + base;
  }
  
  /// Espaciado vertical adaptativo (se reduce cuando aparece el teclado)
  static double verticalSpacing(BuildContext context, double normalSpacing) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return keyboardVisible ? normalSpacing * 0.5 : normalSpacing;
  }
}

/// Extension para facilitar el uso de responsividad
extension ResponsiveContext on BuildContext {
  double get scaleFactor => AppResponsiveConfig.getScaleFactor(this);
  double get horizontalPadding => AppResponsiveConfig.horizontalPadding(this);
  double responsiveFontSize(double baseSize) => AppResponsiveConfig.fontSize(this, baseSize);
  double bottomPadding({double base = 16}) => AppResponsiveConfig.bottomPadding(this, base: base);
  double verticalSpacing(double normalSpacing) => AppResponsiveConfig.verticalSpacing(this, normalSpacing);
  bool get isKeyboardVisible => MediaQuery.of(this).viewInsets.bottom > 0;
}
