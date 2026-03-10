import 'package:flutter/material.dart';

/// Utilidades para hacer las apps responsivas en diferentes tamaños de pantalla
class ResponsiveUtils {
  /// Obtiene el padding inferior seguro considerando el teclado
  static double getBottomPadding(BuildContext context, {double minPadding = 16}) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final safePadding = mediaQuery.padding.bottom;
    
    // Si el teclado está visible, usar solo un padding mínimo
    if (keyboardHeight > 0) {
      return minPadding;
    }
    
    // Si no hay teclado, usar el safe area padding
    return safePadding + minPadding;
  }
  
  /// Calcula el tamaño de fuente responsivo basado en el ancho de pantalla
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    
    // Pantallas pequeñas (< 360px): reducir 10%
    if (width < 360) {
      return baseSize * 0.9;
    }
    
    // Pantallas grandes (> 400px): aumentar 5%
    if (width > 400) {
      return baseSize * 1.05;
    }
    
    return baseSize;
  }
  
  /// Calcula el padding horizontal responsivo
  static double responsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 360) {
      return 16;
    } else if (width > 400) {
      return 28;
    }
    
    return 24;
  }
  
  /// Verifica si el teclado está visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
  
  /// Obtiene la altura disponible considerando el teclado
  static double getAvailableHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height - 
           mediaQuery.viewInsets.bottom - 
           mediaQuery.padding.top - 
           mediaQuery.padding.bottom;
  }
  
  /// Ajusta el espaciado vertical cuando el teclado está visible
  static double adaptiveSpacing(BuildContext context, double normalSpacing) {
    if (isKeyboardVisible(context)) {
      return normalSpacing * 0.5; // Reducir a la mitad cuando el teclado está visible
    }
    return normalSpacing;
  }
}

/// Widget que ajusta automáticamente su contenido cuando aparece el teclado
class KeyboardAwareContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool shrinkWhenKeyboard;
  
  const KeyboardAwareContainer({
    super.key,
    required this.child,
    this.padding,
    this.shrinkWhenKeyboard = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = ResponsiveUtils.isKeyboardVisible(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding ?? EdgeInsets.only(
        left: ResponsiveUtils.responsiveHorizontalPadding(context),
        right: ResponsiveUtils.responsiveHorizontalPadding(context),
        bottom: ResponsiveUtils.getBottomPadding(context),
      ),
      child: child,
    );
  }
}
