{ pkgs, ... }:

# Runtime dependencies for the Brobot Discord bot (~/projects/brobot).
# Brobot streams YouTube audio via the /play slash command, which needs
# ffmpeg on PATH for transcoding and Node.js 20+ to run the bot itself.
# yt-dlp backs YouTube resolution / downloading.
{
  environment.systemPackages = with pkgs; [
    ffmpeg
    nodejs_22
    yt-dlp
  ];
}
