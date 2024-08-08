{...}: let
  nfs_host_name = "poweredge";
  nfs_host_addr = "169.254.90.239";
in {
  fileSystems."/mnt/${nfs_host_name}_video" = {
    device = "${nfs_host_addr}:/SATA_SSD_POOL/video";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/${nfs_host_name}_series" = {
    device = "${nfs_host_addr}:/SATA_SSD_POOL/series";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/${nfs_host_name}_movies" = {
    device = "${nfs_host_addr}:/SATA_SSD_POOL/movies";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/${nfs_host_name}_music" = {
    device = "${nfs_host_addr}:/SATA_SSD_POOL/music";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/${nfs_host_name}_magewe" = {
    device = "${nfs_host_addr}:/SATA_SSD_POOL/magewe";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  fileSystems."/mnt/${nfs_host_name}_torrents_transmission" = {
    device = "${nfs_host_addr}:/SATA_SSD_POOL/torrents_transmission";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  # fileSystems."/mnt/poweredge_enc" = {
  #   device = "poweredge:/SATA_SSD_POOL/enc";
  #   fsType = "nfs";
  #   options = ["rw" "nofail"];
  # };
}
