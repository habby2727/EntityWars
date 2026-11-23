# Despliegue beta en un VPS Ubuntu 24.04

Esta guía presupone un único servidor y una copia de este repositorio. Sustituye todos los valores entre `<...>` por los tuyos; no incluyas los signos. No publiques hasta comprobar los límites y hacer una restauración de prueba. La aplicación usa SQLite para el estado de juego, PostgreSQL para servicios auxiliares y Redis para sesiones y límites. Los volúmenes se conservan al recrear contenedores. No ejecutes `docker compose down -v` ni borres volúmenes.

## 1. Preparar el servidor

En el panel del proveedor instala Ubuntu 24.04 LTS y configura tu clave pública SSH. Accede mediante `ssh -i <ruta_clave_privada> <usuario>@<ip_del_vps>`. Instala actualizaciones con `sudo apt update && sudo apt upgrade` y reinicia si procede. Crea un usuario administrativo sin privilegios de root permanentes, con sudo, y copia su clave pública a `~/.ssh/authorized_keys` (directorio 700, archivo 600). Desde una segunda terminal verifica que puedes entrar con esa clave y usar sudo antes de desactivar acceso SSH por contraseña y de root mediante un archivo en `/etc/ssh/sshd_config.d/`; valida con `sudo sshd -t` y recarga `ssh`. Conserva abierta la sesión anterior hasta probar la nueva.

Con UFW permite primero el puerto SSH que realmente usas, y después HTTP y HTTPS, y habilita el firewall:

```sh
sudo ufw allow <puerto_ssh>/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw enable
sudo ufw status verbose
```

Aplica reglas equivalentes en el firewall del proveedor. Docker puede evitar reglas UFW para puertos publicados: aquí solo Caddy publica 80 y 443. El acceso al socket Docker equivale a root.

## 2. Docker, repositorio y secretos

Instala Docker Engine y el plugin Compose desde el repositorio oficial de Docker para Ubuntu, siguiendo las instrucciones vigentes: [Instalar Docker Engine en Ubuntu](https://docs.docker.com/engine/install/ubuntu/). Comprueba `sudo docker version` y `sudo docker compose version`. Los comandos siguientes suponen un usuario autorizado para usar Docker; si no, antepón `sudo` y protege los archivos correspondientes. No expongas el socket Docker por TCP.

```sh
git clone <url_del_repositorio> entity-wars
cd entity-wars/backend
cp -n .env.prod.example .env.prod
chmod 600 .env.prod
```

Edita `.env.prod` en privado: `SITE_ADDRESS` debe ser el nombre DNS público real, sin protocolo, puerto ni ruta. Genera seis valores independientes con `openssl rand -hex 32` (una ejecución por variable) y colócalos en las variables vacías. No compartas ni pegues los secretos en incidencias, terminales compartidas o Git. Guarda una copia cifrada de `.env.prod` fuera del VPS, separada de las copias de datos. Mantén los mismos secretos entre actualizaciones y restauraciones; cambiar la contraseña de PostgreSQL en el archivo no cambia automáticamente la contraseña de una base ya inicializada. El archivo de ejemplo vacío falla deliberadamente.

Para activar el puente de chat, añade `DISCORD_BOT_TOKEN=<token privado>` a `.env.prod`. Sin token, el puente queda desactivado. Los valores predeterminados son `DISCORD_APPLICATION_ID=1572757742270288033`, `DISCORD_GUILD_ID=1376365043775438871` y `DISCORD_CHANNEL_ID=1572758122810974360`; pueden configurarse en el mismo archivo. Habilita el intent privilegiado Message Content en el portal de Discord y concede al bot acceso de lectura y envío en el canal.

## 3. DNS, HTTPS y arranque

Apunta un registro A del nombre elegido a la IPv4 pública del VPS; añade AAAA solo si IPv6 está configurado, accesible y protegido. Espera a la propagación, verifica los puertos 80 y 443 y que ningún otro proceso los use. Caddy obtiene y renueva certificados automáticamente para el nombre configurado. No uses una IP o nombre inventado para la emisión pública.

Desde `backend/`, con `.env.prod` completado:

```sh
docker compose --env-file .env.prod -f compose.prod.yaml config -q
docker compose --env-file .env.prod -f compose.prod.yaml up -d --build --wait
docker compose --env-file .env.prod -f compose.prod.yaml ps
docker compose --env-file .env.prod -f compose.prod.yaml logs --tail=100 api caddy
docker stats
curl -fsS https://<nombre_dns>/health
curl -i https://<nombre_dns>/metrics
```

Comprueba `postgres: up` y `redis: up` en el JSON, y 404 para `/metrics`. `/health` devuelve HTTP 200 incluso con dependencias caídas: el chequeo del contenedor inspecciona ambos campos. API, PostgreSQL y Redis no publican puertos. CORS no autoriza orígenes web; un cliente nativo no necesita CORS. No cambies `DEBUG_BYPASS`, `DEV_DOCKER_LOCAL_LOGIN` ni el modo production. El límite de clientes es 5504. Solo hay una API; las migraciones SQLite y PostgreSQL se ejecutan antes de cada arranque y un fallo impide iniciarla.

El bosque WebSocket está desactivado por defecto. Activa `FOREST_WS_ENABLED=1` solo después de desplegar y validar F4B. Las API habilitadas deben compartir el mismo Redis primario: una concesión exclusiva impide que dos procesos mantengan salas a la vez, y su pérdida detiene el proceso. Esta concesión depende de un único primario Redis; una conmutación por error que pierda escrituras puede perder la concesión y no ofrece garantías de consenso. Caddy es el único proxy de confianza configurado para el límite de conexiones del bosque.

Límites máximos configurados: API 768 MiB, PostgreSQL 512 MiB, Redis 256 MiB y Caddy 192 MiB (1728 MiB en total). Redis limita datos a 128 MB y usa `noeviction`: al llenarse rechaza escrituras, por lo que hay que vigilarlo. AOF con `everysec` puede perder aproximadamente un segundo de escrituras ante un fallo brusco. Los límites no reservan memoria; deja espacio para Ubuntu, Docker, caché y picos. Observa memoria, disco y crecimiento de PostgreSQL. El worker no es necesario para el juego actual: las acciones encolan trabajos de auditoría de ejemplo que permanecerán en PostgreSQL y pueden hacer crecer la tabla `jobs`; monitorízala y define una política operativa antes de una beta grande. No borres datos automáticamente.

## 4. Cliente Windows

En PowerShell, antes de iniciar el ejecutable beta desde esa misma sesión:

```powershell
$env:ENTITYWARS_BACKEND_URL = 'https://<nombre_dns>'
& '<ruta_al_ejecutable_de_Entity_Wars.exe>'
```

Usa el nombre real del certificado, sin barra final. La pantalla de acceso usa `/auth/register` y `/auth/login`; los accesos de desarrollo no funcionan en producción. El ejecutable debe enviar `X-EntityWars-Client-Build` con un valor al menos 5504. Revisa que la compilación distribuida incluya esa cabecera.

## 5. Actualizar, copias y recuperación

Antes de una actualización, programa una ventana de mantenimiento, registra el commit y la imagen anterior, y realiza y verifica una copia. Obtén el nuevo código revisado, conserva `.env.prod`, y ejecuta de nuevo `up -d --build --wait`. Revisa `ps`, logs, `/health`, acceso y versión. Las migraciones modifican datos; volver a la imagen anterior sin restaurar una copia compatible puede fallar. Para volver atrás de forma consistente, detén el servicio, restaura la copia anterior en volúmenes nuevos y usa el commit y secretos correspondientes. Se pierde todo lo escrito desde esa copia; planifica esa pérdida antes de restaurar.

Para una copia coherente, desde `backend/`:

```sh
sh deploy/backup.sh
```

El script detiene la API y cierra PostgreSQL y Redis, comprueba que se apagaron correctamente, archiva los tres volúmenes y reinicia. Incluye la base SQLite y sus archivos WAL en el mismo volumen, sin copiar una base activa. Si falla, deja los servicios detenidos: revisa el error y vuelve a ejecutar `docker compose --env-file .env.prod -f compose.prod.yaml up -d --wait` cuando sea seguro. Los archivos bajo `backups/` son sensibles; no guardan `.env.prod`. Comprueba los hashes con `cd backups/<fecha> && sha256sum -c SHA256SUMS`. Cifra y copia datos y secretos por canales seguros a almacenamiento externo. Define retención según pérdida aceptable, por ejemplo copias diarias durante 7 días y semanales durante 4 semanas, más una copia anterior a cada despliegue; revisa espacio y caducidad. Los hashes detectan alteraciones, no prueban restaurabilidad.

### Restaurar a volúmenes nuevos

Practica primero en otro servidor aislado, sin DNS público, con el mismo commit y `.env.prod` de la copia. El siguiente procedimiento crea un proyecto nuevo con nombre único; nunca lo uses sobre volúmenes existentes. No arranques Caddy durante la prueba. Construye antes la imagen con `docker compose --env-file .env.prod -f compose.prod.yaml build api`. Desde `backend/`, con la ruta absoluta a una copia confiable:

```sh
backup='<ruta_absoluta_a_la_copia>'
(cd "$backup" && sha256sum -c SHA256SUMS)
project="ew-restore-$(openssl rand -hex 6)"
docker compose -p "$project" --env-file .env.prod -f compose.prod.yaml create api
for volume in sqlite postgres redis; do
  docker volume inspect "${project}_${volume}" >/dev/null || exit 1
  docker run --rm --user 0 --network none \
    --mount "type=volume,source=${project}_${volume},target=/snapshot" \
    --mount "type=bind,source=$backup,target=/backup,readonly" \
    --entrypoint tar entitywars-prod-api:local -xzf "/backup/$volume.tar.gz" -C /snapshot || exit 1
done
docker compose -p "$project" --env-file .env.prod -f compose.prod.yaml up -d --wait api
docker compose -p "$project" --env-file .env.prod -f compose.prod.yaml exec -T api bun -e "const j=await (await fetch('http://127.0.0.1:8787/health')).json(); console.log(j); if(j.postgres!=='up'||j.redis!=='up') process.exit(1)"
```

Examina migraciones, `PRAGMA integrity_check` de SQLite con herramientas apropiadas, datos y acceso con cuentas de prueba, y registra el resultado. La comprobación de salud por sí sola no valida la copia. Para recuperación real, detén el proyecto original y prepara cuidadosamente el proyecto restaurado con Caddy y el DNS correctos; conserva intactos los volúmenes originales hasta confirmar la recuperación. Las imágenes, certificados y configuración de Caddy no forman parte de la copia: Caddy puede obtener certificados de nuevo con DNS y puertos válidos. No restaures archivos de fuentes no confiables.

## 6. Diagnóstico

- **HTTPS/DNS:** consulta logs de Caddy, resuelve el DNS y verifica puertos, IPv6 y límites de emisión del proveedor de certificados.
- **Auth:** confirma HTTPS, nombre/contraseña y que Redis y PostgreSQL estén sanos. Las rutas de desarrollo están bloqueadas. La API aplica límites por IP; Caddy sustituye las cabeceras de IP suministradas por el cliente.
- **Redis:** revisa logs, contraseña y memoria; `noeviction` produce errores de escritura cuando se llena. No borres sesiones para ocultar el problema.
- **PostgreSQL:** revisa logs, disco, credenciales originales, conexiones y migraciones. Cambiar `.env.prod` no rota la contraseña ya guardada.
- **SQLite:** revisa espacio, permisos del volumen y logs de migración; conserva juntos `.sqlite`, `-wal` y `-shm`. No copies ni edites la base activa.
- **VERSION-GATE / 426:** comprueba la cabecera `X-EntityWars-Client-Build`, el valor mínimo 5504 y `/static/version`. Actualiza el cliente cuando corresponda; no reduzcas el mínimo para evitar el control.

Las credenciales de aplicación de ejemplo y la restauración no se consideran validadas hasta probar el flujo completo con datos aislados y registrar el resultado.
