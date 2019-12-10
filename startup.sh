#! /bin/bash    
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl cryptsetup apt-transport-https ca-certificates  google-cloud-sdk

curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh
service google-fluentd start

export PROJECT_ID=`gcloud config get-value core/project`

sec=`gcloud beta secrets versions access 1 --secret csek`
cat <<EOF > csek-key-file.json
    [
    {
    "uri": "https://www.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/us-central1-a/disks/csek-disk",
    "key": "`echo -n $sec | base64`",
    "key-type": "raw"
    }
    ]
EOF

gcloud compute instances attach-disk gce-csek --disk csek-disk --csek-key-file=csek-key-file.json --zone us-central1-a

rm csek-key-file.json

luks=`gcloud beta secrets versions access 1 --secret luks`
DEV_LUKS="/dev/sdb"
cryptsetup isLuks $DEV_LUKS
if [ $? != "0" ]; then
   echo  -n $luks | cryptsetup -v luksFormat /dev/sdb -   
fi

echo  -n $luks | cryptsetup luksOpen /dev/sdb vault_encrypted_volume -

mkdir -p /media/vaultfs
mount /dev/mapper/vault_encrypted_volume /media/vaultfs

if [ $? != "0" ]; then
   mkfs.ext4 /dev/mapper/vault_encrypted_volume
   mount /dev/mapper/vault_encrypted_volume /media/vaultfs 
fi