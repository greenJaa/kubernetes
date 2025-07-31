Task

    create NFS server
        Share folder on your filesystem with k3s server
        Move to shared folder
        Create index.html file the says : "NFS StorageClass To Container"
    Create PV and PVC to be share as storage class
    Create nginx deployment to use PVC
        It should have 3 replicas
        Should have config map that configures nginx to use port 1234
        Mount nginx container to volume PVC and connect it to /usr/share/nginx/html inside nginx container
    Check pod IP address
        Test with curl nginx container

