{...}:
{
  fileSystems."/mnt/poweredge_video" = {
    device = "poweredge:/SATA_SSD_POOL/video";
    fsType = "nfs";
  };
  fileSystems."/mnt/poweredge_music" = {
    device = "poweredge:/SATA_SSD_POOL/music";
    fsType = "nfs";
  };
  fileSystems."/mnt/poweredge_enc" = {
    device = "poweredge:/SATA_SSD_POOL/enc";
    fsType = "nfs";
  };
}
