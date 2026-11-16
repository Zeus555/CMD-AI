#requires -Version 5.1
# ============================================================================
#  providers.ps1 - Los proveedores son DATOS, no codigo.
#  Anadir un proveedor nuevo = anadir una entrada en esta tabla. Nada mas.
#
#  Todos hablan el MISMO dialecto: POST {BaseUrl}/chat/completions y la
#  respuesta sale en choices[0].message.content (o .delta.content en
#  streaming). Ollama y llama-server exponen /v1/chat/completions como ruta
#  de primera clase, asi que no hace falta un segundo parser para el modo
#  local.
#
#  Una entrada no tiene por que ser un servidor distinto: 'gemma', 'gemma3' y 'qwen'
#  son el MISMO llama-server en modo router. Comparten BaseUrl y solo cambia
#  Model, que es el campo con el que el router elige que modelo cargar.
# ============================================================================

# Un solo llama-server (llama.cpp) en modo router (--models-preset) sirve los
# modelos locales por el mismo puerto. Los nombres de modelo son las
# secciones de su fichero de modelos. Si el servicio cambia de puerto,
# se cambia aqui y solo aqui.
$AI_LLAMA_URL  = 'http://127.0.0.1:8080/v1'
# Lo que core.ps1 anade al error cuando nadie escucha en ese puerto: la orden
# que arranca TU servidor. Aqui es un servicio de pm2.
$AI_LLAMA_HINT = 'Arranca el servicio:  pm2 start rpa-ai-portable'

$AI_PROVIDERS = [ordered]@{

    openai = @{
        Label    = 'OpenAI'
        BaseUrl  = 'https://api.openai.com/v1'
        KeyVar   = 'OPENAI_API_KEY'
        Model    = 'gpt-4o-mini'
        NeedsKey = $true
        Stream   = $true
        HideThink = $false
        # OJO: NO mandar max_tokens. Los modelos gpt-5.x lo rechazan con 400 y
        # exigen max_completion_tokens, que a su vez Ollama ignora. Lo unico
        # seguro para todos es no mandar ningun tope de tokens.
        Extra    = @{}
    }

    xai = @{
        Label    = 'xAI'
        BaseUrl  = 'https://api.x.ai/v1'
        KeyVar   = 'XAI_API_KEY'
        Model    = 'grok-4.3'
        NeedsKey = $true
        Stream   = $true
        HideThink = $false
        # reasoning_effort='none' elimina el campo reasoning_content y deja el
        # objeto message identico al de OpenAI y Ollama. Ademas los tokens de
        # razonamiento pasan a 0: el coste baja ~2.7x. Gratis, se manda siempre.
        # Va aqui y NO en el cuerpo comun: OpenAI SI rechaza parametros que no
        # conoce, asi que un extra de un proveedor nunca debe filtrarse a otro.
        Extra    = @{ reasoning_effort = 'none' }
    }

    ollama = @{
        Label    = 'Ollama (local)'
        BaseUrl  = 'http://localhost:11434/v1'
        KeyVar   = 'OLLAMA_API_KEY'
        Model    = 'qwen3:4b'
        NeedsKey = $false          # el shim /v1 acepta el Bearer y lo ignora
        Stream   = $true
        # Los modelos de razonamiento locales meten un bloque <think>...</think>
        # DENTRO de content. Hay que filtrarlo, y no se puede hacer mirando cada
        # fragmento SSE por separado: llegan de 1 a 4 caracteres, asi que la
        # etiqueta casi siempre viene partida ('<thi' + 'nk>'). Ver el
        # acumulador de New-AIThinkFilter en core.ps1.
        HideThink = $true
        Extra    = @{}
    }

    # Desde el 2026-11-14 'gemma' es Gemma 4 E4B: en la comparacion de Gemma
    # Portable (181 preguntas con respuesta libre) acerto el 96,7 % con 1 dato
    # falso, frente al 63,5 % con 57 de Gemma 3 4B. Cuesta ~7,6 s por turno en
    # vez de 4-5. Gemma 3 4B sigue disponible como 'gemma3'.
    gemma = @{
        Label    = 'Gemma 4 E4B (local)'
        BaseUrl  = $AI_LLAMA_URL
        # OJO: no llamarla LLAMA_API_KEY. Esa variable la lee el propio
        # llama-server como su --api-key: guardarla con -SetKey le pondria clave
        # al servidor y dejaria fuera a su interfaz web, que no la envia.
        KeyVar   = 'LOCAL_AI_API_KEY'
        # En modo router el campo model ELIGE el modelo. Tiene que ser, letra
        # por letra y con las mismas mayusculas, el nombre de la seccion
        # [gemma-4-e4b] del fichero de --models-preset: con otro nombre el
        # router contesta HTTP 400 "model '...' not found". La respuesta trae
        # ese mismo nombre, asi que el modo interactivo no avisa
        # "[servido por ...]".
        Model    = 'gemma-4-e4b'
        NeedsKey = $false          # sin --api-key el Bearer se ignora
        Stream   = $true
        HideThink = $true
        # llama-server no abre la respuesta hasta tener el primer token, asi
        # que el plazo de core.ps1 cubre despertar el modelo o cambiarlo (el
        # router descarga uno y carga el otro) MAS la lectura de TODA la
        # entrada. Los 30 s por defecto no llegan con un fichero entubado largo.
        Timeout  = 300
        Hint     = $AI_LLAMA_HINT
        Extra    = @{}
    }

    gemma3 = @{
        Label    = 'Gemma 3 4B (local)'
        BaseUrl  = $AI_LLAMA_URL
        KeyVar   = 'LOCAL_AI_API_KEY'
        Model    = 'gemma-3-4b'    # seccion [gemma-3-4b] del preset
        NeedsKey = $false
        Stream   = $true
        HideThink = $true
        Timeout  = 300
        Hint     = $AI_LLAMA_HINT
        Extra    = @{}
        # Tools = $false: a este modelo no se le ofrecen herramientas
        # (buscar_web, datos_equipo). Gemma 3 4B no sabe pedirlas: con ellas
        # a la vista no llamaba a ninguna y contestaba como si lo hubiera
        # hecho. Medido el 2026-11-15, sin que se hiciera ninguna busqueda:
        # "Segun busqueda web, el dolar esta a 37 cordobas", "la temperatura
        # en Managua es de 32 C", "el Real Madrid gano 3-0" (3 de 3), y con
        # datos_equipo una IP y un porcentaje de bateria inventados. Sin
        # herramientas dice que no puede buscar. /buscar y el atajo de los
        # datos del equipo no dependen de esto y siguen funcionando.
        Tools    = $false
    }

    qwen = @{
        Label    = 'Qwen3 8B (local)'
        BaseUrl  = $AI_LLAMA_URL
        KeyVar   = 'LOCAL_AI_API_KEY'
        Model    = 'qwen3-8b'      # seccion [qwen3-8b] del preset
        NeedsKey = $false
        Stream   = $true
        # Por defecto llama-server saca el razonamiento a reasoning_content,
        # que core.ps1 no lee. El filtro queda de red por si el servidor se
        # lanza con --reasoning-format none y el <think> vuelve a content.
        HideThink = $true
        # Escribe a 5-6 tokens/s frente a los 39 de Gemma: el doble de plazo.
        Timeout  = 600
        Hint     = $AI_LLAMA_HINT
        # Qwen3 razona por defecto: de 1 a 5 minutos en blanco por pregunta en
        # este equipo. El preset ya lleva reasoning-budget = 0; se repite en la
        # peticion para que la consola no dependa de como se lanzo el servidor.
        # Va aqui y NO en 'gemma' por la regla de xai: un extra de un proveedor
        # nunca debe filtrarse a otro.
        Extra    = @{ reasoning_budget_tokens = 0 }
    }
}

# Alias para no romper la memoria muscular de los tres comandos de siempre.
# OJO: Resolve-AIProvider mira los alias ANTES que la tabla, asi que un alias
# con el nombre de una entrada la tapa. Por eso 'gemma', 'gemma3' y 'qwen' NO
# estan aqui: son entradas.
$AI_ALIASES = @{
    gpt      = 'openai'; chatgpt = 'openai'; oai = 'openai'
    grok     = 'xai';    x       = 'xai'
    deepseek = 'ollama'; local   = 'ollama'; ds = 'ollama'
    gemma4   = 'gemma';  e4b     = 'gemma'
    llama    = 'gemma';  llamacpp = 'gemma'
    qwen3    = 'qwen'
}

function Resolve-AIProvider {
    <#  Devuelve la tabla del proveedor a partir de un nombre o alias.  #>
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = 'gemma' }
    $k = $Name.Trim().ToLowerInvariant()
    if ($AI_ALIASES.ContainsKey($k)) { $k = $AI_ALIASES[$k] }

    if (-not $AI_PROVIDERS.Contains($k)) {
        $validos = (@($AI_PROVIDERS.Keys) + @($AI_ALIASES.Keys)) -join ', '
        throw "Proveedor desconocido '$Name'. Validos: $validos"
    }

    # Clone para que /model y /provider no muten la tabla original.
    [hashtable]$p = $AI_PROVIDERS[$k].Clone()
    $p.Id = $k
    return $p
}
