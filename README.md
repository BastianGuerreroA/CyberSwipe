# CyberSwipe

<p align="center">
  <strong>Videojuego serio móvil para la concientización y toma de decisiones en ciberseguridad para PYMEs</strong><br>
  <em>Desarrollado en Godot Engine 4 — Universidad de Santiago de Chile (USACH)</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Godot%20Engine-4.5.1-478CBF?logo=godot-engine&logoColor=white" alt="Godot 4.5.1">
  <img src="https://img.shields.io/badge/Plataforma-Android%20%7C%20Desktop-3DDC84?logo=android&logoColor=white" alt="Plataforma">
</p>

---

## Descripción General

**CyberSwipe** es un videojuego serio (*Serious Game*) móvil diseñado para entrenar y concientizar a directivos, colaboradores y profesionales de pequeñas y medianas empresas (PYMEs) en la prevención y respuesta ante incidentes basicos de ciberseguridad.

Inspirado en mecánicas de toma de decisiones rápidas mediante deslizamiento (*swipe* lateral de cartas), el jugador asume el rol del responsable de seguridad informática de una organización. Cada decisión afecta en tiempo real cuatro indicadores críticos:

- **Confidencialidad (C):** Protección de la información sensible contra accesos no autorizados.
- **Integridad (I):** Exactitud y confiabilidad de los datos y sistemas corporativos.
- **Disponibilidad (D):** Accesibilidad continua de los servicios y plataformas del negocio.
- **Presupuesto (P):** Recursos financieros disponibles para la gestión operativa y tecnológica.

Si cualquiera de estos indicadores cae a cero, la organización colapsa y la partida finaliza.

---

## Características Principales

- **Mecánica Dinámica de Swipe:** Evaluación intuitiva de dilemas éticos, técnicos y procedimentales arrastrando cartas a izquierda o derecha.
- **Cápsulas de Aprendizaje Descargables:** Contenido modular basado en incidentes reales (Phishing, Ransomware, Políticas de Contraseñas, Respaldos, etc.), descargables y actualizables dinámicamente desde GitHub sin reinstalar el juego.
- **Modo Estudio / Inducción:** Pantalla de formación teórica previa al inicio de cada módulo para reforzar conceptos clave antes de la evaluación práctica.
- **Modo Speedrun / Contrarreloj:** Desafío contrarreloj para cada cápsula, con penalizaciones de tiempo ante respuestas incorrectas y guardado de récords personales.
- **Tienda de Ventajas y Mecánicas Modificables LSG:** Canje de puntos del perfil multidimencional de LSG por ventajas de partida (Consultoría Preventiva, Análisis de Impacto predictivo, Subsidio de Seguridad, Ciberseguro Activo y Salvavidas de emergencia).

---

### 1. Modo Autónomo (Offline)

- **Cero dependencia externa:** El juego incluye semillas base preinstaladas en `res://resources/data/capsules/` que se cargan automáticamente la primera vez que se inicia la aplicación.
- **Progreso persistente:** El progreso del jugador, estrellas obtenidas, puntajes máximos y récords de tiempo se guardan localmente en `user://progreso_usuario.tres`.
- **Buffer de telemetría seguro:** Si no hay conexión o el servidor no responde, los eventos y checkpoints pedagógicos se encolan en `user://telemetry_queue.json` y se conservan para su posterior envío.

### 2. Modo Conectado (Plataforma LSG - DIINF USACH)

- **Autenticación Institucional:** Inicio de sesión con cuenta de la plataforma mediante `lsg-auth` (JWT).
- **Gestión de Sesiones:** Apertura y cierre formal de sesiones de videojuego con `lsg-core-api` (Game ID: `54`).
- **Telemetría en Tiempo Real:** Emisión automática de registros de interacción y decisiones a la plataforma de investigación educativa LSG.
- **Sincronización Transaccional (*Flush*):** Al iniciar sesión con conexión, el sistema vacía secuencialmente el buffer offline enviando todas las partidas y checkpoints pendientes.

---

## Requisitos del Sistema

### Para Jugadores (Dispositivo Móvil Android)

| Componente | Requisito Mínimo | Requisito Recomendado |
| :--- | :--- | :--- |
| **Sistema Operativo** | Android 8.0 (Oreo / API 26) | Android 11.0 o superior |
| **Arquitectura** | ARM64 (`arm64-v8a`) | ARM64 (`arm64-v8a`) |
| **Memoria RAM** | 2 GB | 3 GB o superior |
| **Almacenamiento** | 100 MB libres | 200 MB libres |
| **Conexión a Internet** | No requerida (juego offline disponible) | Wi-Fi / Datos móviles para sincronización LSG y GitHub |

### Para Desarrolladores (Entorno de Trabajo)

- **Motor:** [Godot Engine 4.5.1](https://godotengine.org/) (o versión compatible 4.3+).
- **Control de Versiones:** Git 2.30+.
- **Herramientas de Exportación Android (Opcional):**
  - Android SDK Command-line Tools y Android SDK Build-Tools (34+).
  - OpenJDK 17.
  - Plantillas de exportación de Godot 4 correspondientes a la versión instalada.

---

## Instalación y Ejecución

### Opción A: Instalación en Dispositivo Android (Jugador)

1. Descarga el paquete de instalación `CyberSwipe.apk` desde la sección de **Releases** de este repositorio o mediante el enlace provisto.
2. En tu dispositivo Android, habilita la opción de instalar aplicaciones desde **Fuentes Desconocidas** en los ajustes de seguridad del navegador o explorador de archivos.
3. Abre el archivo `.apk` descargado y confirma la instalación.
4. Inicia la aplicación.

### Opción B: Ejecución desde el Código Fuente (Desarrollador)

1. Clona el repositorio en tu equipo local.
2. Inicia **Godot Engine 4** y pulsa en **Importar**.
3. Selecciona la carpeta del proyecto y abre el archivo `project.godot`.
4. Ejecuta el proyecto del juego.

---

## Sincronización y Cambio de Repositorio de Contenido

CyberSwipe desacopla el contenido educativo del binario del juego mediante la clase `ContentManager`. Las cápsulas educativas están empaquetadas en formato cifrado `.lsg` (AES-256-CBC con padding PKCS7) para preservar la integridad pedagógica de las evaluaciones.

- **Repositorio actual de contenido:** [CyberSwipe-Content en GitHub](https://github.com/BastianGuerreroA/CyberSwipe-Content)

### ¿Cómo cambiar el repositorio de descarga de recursos?

Si deseas bifurcar (*fork*), personalizar o utilizar tu propio repositorio público de GitHub para distribuir nuevas cápsulas educativas, sigue estos pasos:

1. **Crear o clonar tu repositorio de contenido:**
   Asegúrate de que tu repositorio tenga una carpeta `content/` que contenga:
   - `index.lsg`: Archivo de índice general con la metadata y lista de cápsulas disponibles.
   - `capsule_001.lsg`, `capsule_002.lsg`, etc.: Archivos binarios cifrados de cada módulo.

2. **Modificar la URL en el código fuente:**
   Abre el archivo [src/autoloads/content_manager.gd](file:///d:/ProyectosGodot/cyber-swipe/src/autoloads/content_manager.gd) y localiza la constante `GITHUB_API_URL`.

3. **Verificación:**
   Al iniciar el juego con conexión a internet, `ContentManager` consultará la API de tu repositorio, comparará los archivos locales en `user://capsules/` y descargará automáticamente el nuevo contenido sin necesidad de recompilar la aplicación.

---

## Estructura del Proyecto

```plaintext
cyber-swipe/
├── assets/                    # Texturas, fuentes tipográficas, iconos pixel art y música
│   ├── Fuente/                # Fuentes TTF retro/pixel
│   ├── IconosPixelArt/        # Iconografía CID, presupuesto, reloj y medallas
│   └── Musica/                # Efectos de audio y pistas de fondo
├── docs/                      # Diagramas de arquitectura UML, GDD y manuales
├── resources/                 # Recursos de datos base
│   └── data/capsules/         # Cápsulas semilla iniciales (.lsg pre-empaquetadas)
├── src/
│   ├── api/                   # Clientes REST para la plataforma LSG
│   │   ├── ApiAuth.gd         # Autenticación JWT y Whoami
│   │   ├── ApiCore.gd         # Sesiones, puntos y canjes
│   │   └── LsgLogger.gd       # Telemetría pedagógica y buffer offline
│   ├── autoloads/             # Singletons globales de Godot
│   │   ├── capsula_manager.gd # Catálogo de cápsulas y registros speedrun
│   │   ├── content_manager.gd # Sincronización remota desde GitHub
│   │   ├── CryptoManager.gd   # Descifrado AES-256-CBC con PKCS7
│   │   ├── performance_logger.gd # Registro de rendimiento (FPS/RAM/CPU/Batería)
│   │   └── progreso_usuario.gd # Serialización de progreso del jugador (.tres)
│   ├── gameplay/              # Mecánicas jugables y escenas de partida
│   │   ├── capsula_item/      # Elemento acordeón de selección de módulo
│   │   ├── card/              # Lógica de arrastre de cartas (Swipe)
│   │   ├── icons/             # Tríada CID y previsualización de impacto
│   │   ├── main_stage/        # Escena principal y orquestador de cartas
│   │   └── study_stage/       # Módulo teórico de inducción previa
│   └── ui/                    # Interfaces de usuario y menús
│       ├── capsula_selector/  # Selector de módulos y avance global
│       ├── game_over/         # Pantalla de derrota y consejo pedagógico
│       ├── game_winner/       # Pantalla de victoria, estrellas y speedrun
│       ├── global_summary/    # Resumen cualitativo de competencias
│       ├── login/             # Modal de inicio de sesión LSG
│       ├── main_menu/         # Menú principal y estado de sincronización
│       ├── multidimensional_profile/ # Perfil de 4 dimensiones
│       ├── pause_menu/        # Menú de pausa durante la partida
│       └── store/             # Tienda de ventajas modificables
├── export_presets.cfg         # Configuración de empaquetado para Android
└── project.godot              # Configuración principal del motor Godot 4
```
