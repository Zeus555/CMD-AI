#requires -Version 5.1
# ============================================================================
#  providers.ps1 - Los proveedores son DATOS, no codigo.
#  Anadir un proveedor nuevo = anadir una entrada en esta tabla. Nada mas.
#
#  Los tres hablan el MISMO dialecto: POST {BaseUrl}/chat/completions y la
#  respuesta sale en choices[0].message.content (o .delta.content en
#  streaming). Ollama expone /v1/chat/completions como ruta de primera clase,
#  asi que no hace falta un segundo parser para el modo local.
# ============================================================================

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
        # seguro para los tres es no mandar ningun tope de tokens.
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
}

# Alias para no romper la memoria muscular de los tres comandos de siempre.
$AI_ALIASES = @{
    gpt      = 'openai'; chatgpt = 'openai'; oai = 'openai'
    grok     = 'xai';    x       = 'xai'
    deepseek = 'ollama'; local   = 'ollama'; ds = 'ollama'
}

function Resolve-AIProvider {
    <#  Devuelve la tabla del proveedor a partir de un nombre o alias.  #>
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = 'xai' }
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
