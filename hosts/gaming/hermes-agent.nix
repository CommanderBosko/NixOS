{ pkgs, ... }:

# Ollama (CUDA backend) + Hermes Agent for gaming.
#
# Ollama exposes an OpenAI-compatible API at http://localhost:11434/v1.
# Hermes Agent is configured to use that local endpoint so no upstream API key
# is required.  model.api_key is set to a non-empty dummy because the OpenAI
# client library rejects an empty string before the request reaches Ollama
# (which ignores the key entirely).
#
# Model: qwen2.5:7b (128K context window).
# Hermes Agent enforces a hard 64K minimum context length.  qwen2.5:14b has
# only 32K context (hard-coded in its GGUF), which causes a ValueError at
# agent init.  qwen2.5:7b has 128K context and superior tool-calling vs
# llama3.1:8b at the same ~5 GB VRAM footprint on the RTX 3070.
#
# The systemd service runs as the "hermes" system user under /var/lib/hermes.
# addToSystemPackages = true puts the `hermes` CLI on the system PATH and
# exports HERMES_HOME=/var/lib/hermes/.hermes system-wide so interactive shells
# share state with the gateway service.
#
# /var/lib/hermes is created with mode 2770 (hermes:hermes).  bosko must be in
# the hermes group so the interactive CLI can stat/read the .env file inside it
# without hitting EPERM (Python's pathlib.Path.exists() raises on permission
# denied rather than returning False).
{
  hardware.nvidia-container-toolkit.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [ "qwen2.5:7b" ];
  };

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings = {
      model = {
        provider = "custom";
        default = "qwen2.5:7b";
        base_url = "http://localhost:11434/v1";
        # Non-empty dummy — the OpenAI client requires a non-empty api_key
        # field; Ollama ignores its value.
        api_key = "ollama";
        api_mode = "chat_completions";
      };
    };
  };

  # Grant bosko read/write access to /var/lib/hermes so the interactive `hermes`
  # CLI (which inherits HERMES_HOME=/var/lib/hermes/.hermes) can traverse the
  # service state directory.  The hermes group is only created on gaming by the
  # module above, so this lives here rather than in the shared users.nix.
  users.users.bosko.extraGroups = [ "hermes" ];
}
