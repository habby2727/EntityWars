# Entity Wars — Pack de pantallas de carga animadas (Godot 4.6)

**3 diseños diferentes**, con los títulos **Entity Wars** y **Loading** ya integrados en las ilustraciones.
El texto y el fondo son PNG fijos, mientras que las **barras se dibujan y animan en tiempo real**
por un shader de Godot (el progreso no está grabado en un GIF ni en un vídeo).

## Contenido

- `entity_wars_loading/backgrounds/`: 3 PNG reales **1920 × 1080** (resolución comprobada).
- `entity_wars_loading/scenes/`: 3 escenas independientes, listas para instanciar.
- `entity_wars_loading/scripts/loading_screen.gd`: controla la carga y el progreso.
- `entity_wars_loading/shaders/loading_fill.gdshader`: gradiente cian/violeta animado y brillo móvil.
- `entity_wars_loading/demo/`: demostración interactiva (progreso **simulado solo aquí**).
- `project.godot`: miniproyecto independiente de prueba; **no copiar sobre el project.godot de Entity Wars**.

## Probar rápidamente

1. Descomprime el ZIP y abre la carpeta completa `EntityWars_LoadingScreens_Godot46/` con Godot 4.6.
2. Pulsa F6 con `entity_wars_loading/demo/loading_demo.tscn` abierto, o ejecuta F5 en el miniproyecto.
3. **Flecha derecha / Espacio**: siguiente diseño. **Flecha izquierda**: anterior. **R**: reiniciar barra.
4. La demo tarda visualmente ~7 s de 0 al 100 %, **no hace una carga real**.

## Integrar en el proyecto Entity Wars existente

1. Copia **solamente la carpeta `entity_wars_loading`** al directorio raíz del proyecto Godot.
   Debe quedar `res://entity_wars_loading/scenes/loading_portal.tscn`, etc.
2. Coloca la pantalla en la escena que corresponda o instánciala por código.
3. Controla el porcentaje desde tu código, con valores **de `0.0` a `1.0`**:

```gdscript
var loading_screen = preload("res://entity_wars_loading/scenes/loading_portal.tscn").instantiate()
add_child(loading_screen)
loading_screen.set_progress(0.0)
# Cuando de verdad alcances el 42 %:
loading_screen.set_progress(0.42)
# Cuando completes tu flujo:
loading_screen.set_progress(1.0)
```

Si quieres que el recurso de la escena de destino se cargue en segundo plano, también puedes usar:

```gdscript
var loading_screen = preload("res://entity_wars_loading/scenes/loading_chaos.tscn").instantiate()
get_tree().root.add_child(loading_screen)
loading_screen.load_scene_threaded("res://scenes/Combat.tscn")  # Cambiar por tu escena REAL
```

Cuando termina la carga, el script muestra el 100 % brevemente y cambia de escena mediante
`get_tree().change_scene_to_packed()`. Si deseas solo el efecto animado sin un porcentaje conocido:

```gdscript
loading_screen.start_indeterminate()
# Más tarde: loading_screen.set_progress(progreso_real)
```

El efecto indeterminado es **decorativo** y no representa un porcentaje de carga real.

### Precaución de integración

El `load_scene_threaded()` sirve para transiciones basadas en **una escena PackedScene**. Para
procesos de servidor, autenticación, petición HTTP o varias etapas independientes usa
`set_progress()` y realiza la transición en tu propio código cuando todo haya terminado.
No conectes directamente progreso de descarga al porcentaje de carga local sin sumar sus fases.

### Tamaño y calidad

- Tamaño de **cada ilustración: 1920×1080 píxeles exactos**, 16:9.
- Se mantuvo la relación de aspecto original, ampliando con Lanczos y recorte de ~1 px.
- Barra con máscara visual y relleno animado (shader), sin textura GIF.
- Sin complementos, sin fuentes externas, sin dependencias de terceros.
- Material del shader duplicado por instancia para evitar que dos escenas compartan progreso.
- Los elementos están alineados para 16:9; otros formatos usan cobertura/crop del fondo.

## Rutas de las escenas

`res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_portal.tscn`
`res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_chaos.tscn`
`res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_laboratory.tscn`
