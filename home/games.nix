{pkgs, ...}: {
  home.packages = with pkgs; [
    mindustry
    steam
    beyond-all-reason
    # hyperspeedcube # 3D and 4D Rubik's cube simulator
  ];
}
