#!/bin/bash

echo "Setting up Ceph demo environment via setup.sh"

# start the docker service and deamon
apt-get update
apt-get install -y docker.io
apt-get install -y awscli
dockerd &

echo "Docker service started, waiting for it to be ready"


while ! docker info > /dev/null 2>&1; do
    echo "Waiting for Docker to start..."
    sleep 2
done
echo "Docker is ready"
# Login to container registry
#docker login -u= -p=
docker login -u='19165611|ceph-portal' -p='eyJhbGciOiJSUzUxMiJ9.eyJzdWIiOiJkZTI1NmJhZDk5Nzk0NGQ5OTk2ZjI1NzA2M2U0NjVhZSJ9.Iss5SBaMe2ZJkoSswDQrAG-srbAGGTGyO7LTf-u2NlnV1-jr403z98nuDRa1WlgDyA98-wsj2WH2yeJ7YFz5xvit06tBIxqiPqwcYkzDecjBs6QQ32ViAITZzGGUnjInuhqABh6oLgGaFU2zGdZe8qJW7Z8DlTEsdT-UHr8KFkCyluo9ERVfaFx_1g-iD_RB41vl6svJudoE3IazaxdWrkXzQD5mCxLmB0y3B8xbl1o5-lgsDFznisoJANn6CadauX4sL8CJ8aQCaWWB2mzB2ckjerYwKaj1ms69rXXSzKqxs_J9Q6YBQuw6LJJCtMc2LffKuwGrDuryDVcrzdO4Uty0Rz4LlRcizIEN319SrTI5wyuvqiJPFgAFrU3ahBU-E1vxBkEBc4iJmFAzS5VP8NNbbroE4fCySq6fzNDkzm_DcltfBs5Rq6Iakp0vVFnfkBXygb6_AhWxQb2H2S5Xgrt1VKCh-pZ3OimcKhpOp4KvgcGRHiU7HeU0GqhinLI51LIdpdXSKrEFfqVMIgL3G9iV4E21uW_pV5w8-IU7x70DNG0uUBQMlCnxOeoXfh7ffYt11un74XI3lVX1hsRGJ04vo1h4-aPmM7J4vU3cLtSKFhIAH9meWP0C0JG22IqAvnVNUT39tuB7t_J7Yh05QUCJJavBw7giXxDQ_zPY1oM' registry.redhat.io
echo "Logged into container registry"

# Run the Ceph demo container
docker run -d --name demo --net host \
-e MON_IP=${MON_IP} \
-e CEPH_PUBLIC_NETWORK=${CEPH_PUBLIC_NETWORK} \
-e CEPH_DEMO_UID=${CEPH_DEMO_UID} \
-e CEPH_DEMO_ACCESS_KEY=${CEPH_DEMO_ACCESS_KEY} \
-e CEPH_DEMO_SECRET_KEY=${CEPH_DEMO_SECRET_KEY} \
registry.redhat.io/rhceph/rhceph-4-rhel8 demo

docker ps

echo "Ceph demo container started"

# Wait for the Ceph demo container to be ready
sleep 20

#echo "Ceph demo container ready, checking status"

# Check Ceph status
#docker exec -it demo ceph status


echo "Ceph demo environment setup complete"
echo "Starting S3 demo"

# Configure AWS CLI
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# Create an S3 bucket and upload a file
aws s3 mb s3://test --endpoint-url http://192.168.0.3:8080
aws s3 cp /etc/hosts s3://test --endpoint-url http://192.168.0.3:8080

# List the contents of the S3 bucket
aws s3 ls s3://test --endpoint-url http://192.168.0.3:8080

# Create Flask Container
cd /usr/local/bin/app
docker build -t flaskcedi .
docker image ls
docker run -p 5000:5000 flaskcedi


# Run a loop to keep the container running
tail -f /dev/null

