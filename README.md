# Nginx + NFS on Kubernetes

This project sets up an Nginx deployment on Kubernetes that mounts a shared NFS volume.

## Requirements
- Able to sudo 
- Kubernetes cluster
- NFS server installed and running
- kubectl access to the cluster

## Steps
   Clone the project
   
   Set up the NFS server:
   ```bash
   sudo apt update
   sudo apt install -y nfs-kernel-server
   sudo mkdir -p /srv/nfs/shared
   sudo chown nobody:nogroup /srv/nfs/shared
   echo "/srv/nfs/shared 192.168.68.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports
   sudo exportfs -ra
   sudo systemctl enable nfs-server --now

   #Run the install script with sudo:

   sudo bash install.sh

   #Test access:
   
   curl http://<nginx-pod-ip>:1234
