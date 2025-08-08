{pkgs, ...}: {
  home.packages = with pkgs; [
    mindustry
    steam
    minetest
    beyond-all-reason
    # hyperspeedcube # 3D and 4D Rubik's cube simulator
  ];
}
