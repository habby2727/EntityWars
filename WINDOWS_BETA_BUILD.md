# Compilar la beta de Windows

La versión de lanzamiento usa `https://entitywars.duckdns.org` y verifica los certificados TLS con Godot. En el editor se usa `http://127.0.0.1:8787` por defecto; `ENTITYWARS_BACKEND_URL` solo se admite como alternativa en el editor. La beta no necesita variables de entorno.

## Exportar

1. Abre el proyecto con **Godot 4.6.stable**. En **Editor > Manage Export Templates**, instala las plantillas oficiales que coincidan exactamente con esa versión. Se necesitan las plantillas de Windows x86_64, tanto debug como release.
2. Crea la carpeta `dist/EntityWars-Beta-Windows-x64/`. En **Project > Export**, selecciona **Windows Beta x64**, elige **Export Project**, desmarca **Export With Debug** y guarda como `dist/EntityWars-Beta-Windows-x64/EntityWars.exe`. El preset genera un EXE y un PCK separado. La firma está desactivada; Windows puede advertir que el editor es desconocido.
3. Comprueba que estén `EntityWars.exe` y `EntityWars.pck`, sin logs ni archivos adicionales de desarrollo. Selecciona ambos y comprímelos en un ZIP, por ejemplo `EntityWars-Beta-Windows-x64.zip`, dentro de `dist/`. No subas los binarios al repositorio.

Opcionalmente, desde PowerShell en la raíz del proyecto, con la ruta real a Godot:

```powershell
New-Item -ItemType Directory -Force dist/EntityWars-Beta-Windows-x64 | Out-Null
$godot = '<ruta-a-Godot_v4.6.exe>'
$process = Start-Process -FilePath $godot -ArgumentList '--headless','--path','.','--export-release','"Windows Beta x64"','dist/EntityWars-Beta-Windows-x64/EntityWars.exe' -Wait -PassThru
if ($process.ExitCode -ne 0) { throw 'La exportación falló' }
if (!(Test-Path dist/EntityWars-Beta-Windows-x64/EntityWars.exe) -or !(Test-Path dist/EntityWars-Beta-Windows-x64/EntityWars.pck)) { throw 'Faltan archivos exportados' }
Compress-Archive -Path dist/EntityWars-Beta-Windows-x64/EntityWars.exe,dist/EntityWars-Beta-Windows-x64/EntityWars.pck -DestinationPath dist/EntityWars-Beta-Windows-x64.zip
```

El PCK incluye los JSON de `data/`, escenas, texturas, fuentes y traducciones; el backend, los archivos de entorno, bases SQLite y pruebas se excluyen.

## Prueba antes de distribuir

Extrae el ZIP en un equipo Windows x64 limpio, sin Godot, variables de entorno ni archivos del proyecto. Abre `EntityWars.exe`, verifica la pantalla inicial y crea una cuenta de prueba o inicia sesión con una existente. Comprueba la recuperación de sesión al reiniciar, menú, idiomas, recursos, chat, Hunt y Dungeon. No uses credenciales reales durante pruebas no autorizadas. El servidor y su certificado deben estar disponibles; la exportación local no verifica esa disponibilidad.

Si no conecta, comprueba DNS, conexión a Internet, reloj de Windows, certificado válido para el hostname y disponibilidad del servidor. No desactives la verificación TLS. Ante avisos del sistema para un ejecutable sin firma, verifica la procedencia del ZIP antes de autorizarlo.

El cliente envía la build **5504**. Antes del acceso consulta `/static/version`; si el servidor exige una versión superior, o responde 426, se muestra el estado que pide actualizar. Para una versión futura, cambia `BUILD` en `scripts/net/client_build.gd` solo al coordinar la compatibilidad con el servidor, ejecuta las pruebas, vuelve a exportar y distribuye un ZIP nuevo. No reduzcas el mínimo del servidor para evitar el control.
