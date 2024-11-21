from pathlib import Path
import psutil  # This library can be used to monitor disk health and status

class DiskStatusHandler:
    def __init__(self):
        self.disks = self._get_all_disks()

    def _get_all_disks(self) -> list[dict]:
        """
        Collect and return all disk information (health, partitions, etc.).
        """
        disks = []
        for partition in psutil.disk_partitions(all=False):  # 'all=False' excludes unmounted partitions
            disk_info = {
                'device': partition.device,
                'mountpoint': partition.mountpoint,
                'fstype': partition.fstype,
                'opts': partition.opts,
                'partitions': self._get_disk_partitions(partition.device),  # Get partitions of the disk
                'usage': self._convert_bytes_to_gb(psutil.disk_usage(partition.mountpoint)._asdict())  # Disk usage stats
            }
            disks.append(disk_info)
        return disks

    def _get_disk_partitions(self, device: str) -> list[dict]:
        """
        Retrieve partition details for a specific device.
        """
        partitions = []
        for partition in psutil.disk_partitions(all=False):  # 'all=False' excludes unmounted partitions
            if partition.device == device:
                partition_info = {
                    'device': partition.device,
                    'mountpoint': partition.mountpoint,
                    'fstype': partition.fstype,
                    'opts': partition.opts,
                    'usage': self._convert_bytes_to_gb(psutil.disk_usage(partition.mountpoint)._asdict())  # Disk usage stats
                }
                partitions.append(partition_info)
        return partitions

    def _get_disk_health(self, device: str) -> str:
        """
        Use SMART (Self-Monitoring, Analysis, and Reporting Technology) to check the disk health.
        """
        try:
            import subprocess
            result = subprocess.run(
                ['smartctl', '-a', device], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True
            )
            return result.stdout.decode('utf-8')
        except Exception as e:
            return f"Failed to fetch SMART data for {device}: {str(e)}"

    def _convert_bytes_to_gb(self, usage: dict) -> dict:
        """
        Convert disk usage values from bytes to GB.
        """
        return {
            'total': usage['total'] / (1024 ** 3),  # Convert bytes to GB
            'used': usage['used'] / (1024 ** 3),
            'free': usage['free'] / (1024 ** 3),
            'percent': usage['percent']
        }

    def get_disk_status(self) -> None:
        """
        Print the status of all detected disks including their health, usage, and partitions.
        """
        print("Disk Status Report")
        print("====================")

        for disk in self.disks:
            print(f"Disk: {disk['device']}")
            print(f"  - Filesystem: {disk['fstype']}")
            print(f"  - Mountpoint: {disk['mountpoint']}")
            print(f"  - Options: {disk['opts']}")
            print(f"  - Usage: Total: {disk['usage']['total']:.2f} GB, "
                  f"Used: {disk['usage']['used']:.2f} GB, Free: {disk['usage']['free']:.2f} GB, "
                  f"Percent: {disk['usage']['percent']}%")

            # Get the health status using SMART data
            health_info = self._get_disk_health(disk['device'])
            print(f"  - Health Status: {health_info}")

            for partition in disk['partitions']:
                print(f"    - Partition: {partition['device']}")
                print(f"      - Filesystem: {partition['fstype']}")
                print(f"      - Mountpoint: {partition['mountpoint']}")
                print(f"      - Usage: Total: {partition['usage']['total']:.2f} GB, "
                      f"Used: {partition['usage']['used']:.2f} GB, Free: {partition['usage']['free']:.2f} GB, "
                      f"Percent: {partition['usage']['percent']}%")

            print("\n")
            
            
def showDiskStatus():
    disk_status_handler = DiskStatusHandler()
    disk_status_handler.get_disk_status()