#!/bin/bash

set -e

sdk_version=1.0
web_server="https://chat-sdk.mode.ai"
distribution_id=E2FD9F88Z4UNXG


rm -f builds.txt
if aws s3 cp s3://${MODEAI_SDK_S3_BUCKET}/${MODEAI_SDK_S3_PATH}/builds.txt ./builds.txt; then
    last_ver=$(tail -1 builds.txt)
    if [[ "${last_ver}" =~ ^${sdk_version} ]]; then
        last_build_num=${last_ver#${sdk_version}.}
    else
        last_build_num=0
    fi
    builds=$(tail -9 builds.txt)
    echo "$builds" > builds.txt
else
    last_build_num=0
fi
last_build_num=$((last_build_num += 1))
package_name_prefix=modeai-chat-sdk-${sdk_version}
package_name=${package_name_prefix}.${last_build_num}
zip -r ${package_name}.zip Smooch.framework
echo $sdk_version.$last_build_num >> builds.txt
aws s3 cp --acl public-read ${package_name}.zip s3://${MODEAI_SDK_S3_BUCKET}/${MODEAI_SDK_S3_PATH}/
aws s3 cp builds.txt s3://${MODEAI_SDK_S3_BUCKET}/${MODEAI_SDK_S3_PATH}/builds.txt

python -c "import json; lines=open('builds.txt').readlines(); spec={v.strip():'${web_server}/${MODEAI_SDK_S3_PATH}/${package_name_prefix}.{}.zip'.format(v.strip().split('.')[-1]) for v in lines}; print json.dumps(spec, indent=4, sort_keys=True)" > modeai-chat-sdk.json
aws s3 cp --acl public-read modeai-chat-sdk.json s3://${MODEAI_SDK_S3_BUCKET}/${MODEAI_SDK_S3_PATH}/

aws cloudfront create-invalidation --distribution-id $distribution_id --paths "/${MODEAI_SDK_S3_PATH}/modeai-chat-sdk.json" "/${MODEAI_SDK_S3_PATH}/${package_name}.zip"
