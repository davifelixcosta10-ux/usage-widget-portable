#!/usr/bin/env bash
# Instruções para NixOS (não executa — adiciona ao configuration.nix)
cat <<'NIXEOF'
# usage-widget no NixOS
# Adicione ao seu configuration.nix:

{ config, pkgs, ... }: {
  # 1. Quickshell
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;  # ou quickshell-git se quiser bleeding edge
  };

  # 2. Python com psutil
  environment.systemPackages = with pkgs; [
    python3Packages.psutil
    # ferramentas base
    iproute2
    iputils
    wireless-tools  # iw
    lm_sensors
  ];

  # 3. ccusage (opcional)
  # environment.systemPackages = with pkgs; [ nodePackages.ccusage ];

  # 4. Nossos scripts (coloque no seu dotfiles ou use home-manager)
  # home-manager users.seu-usuario = { pkgs, ... }: {
  #   home.packages = with pkgs; [ (writeShellScriptBin "usage-widget" ''
  #     ${pkgs.bash}/bin/bash ${pkgs.quickshell}/bin/quickshell -c usage-widget --no-duplicate --daemonize
  #   '') ];
  # };

  # 5. Serviços (opcional: systemd user service para auto-start)
  # systemd.user.services.usage-widget = {
  #   description = "Usage Widget";
  #   wantedBy = [ "graphical-session.target" ];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.quickshell}/bin/quickshell -c usage-widget --no-duplicate --daemonize";
  #     Environment = "MALLOC_CONF=dirty_decay_ms:0,muzzy_decay_ms:0,retain:false,narenas:2";
  #   };
  # };
}
NIXEOF
echo "   Veja saída acima para configuration.nix"
