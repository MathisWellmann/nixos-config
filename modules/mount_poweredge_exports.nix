{...}: {
  fileSystems."/mnt/poweredge_video" = {
    device = "poweredge:/SATA_SSD_POOL/video";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/poweredge_series" = {
    device = "poweredge:/SATA_SSD_POOL/series";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/poweredge_movies" = {
    device = "poweredge:/SATA_SSD_POOL/movies";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/poweredge_music" = {
    device = "poweredge:/SATA_SSD_POOL/music";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  # fileSystems."/mnt/poweredge_enc" = {
  #   device = "poweredge:/SATA_SSD_POOL/enc";
  #   fsType = "nfs";
  #   options = ["rw" "nofail"];
  # };
}
