#!/bin/bash -eu
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

BUILD_OPTS="$*"

DOCKER="docker"

IMG_NAME="openhd"

IMAGE_ARCH=$1
DISTRO=$2

WORK_DIR=-f"work-${IMAGE_ARCH}-${DISTRO}"

if ! ${DOCKER} ps >/dev/null 2>&1; then
	DOCKER="sudo docker"
fi
if ! ${DOCKER} ps >/dev/null; then
	echo "error connecting to docker:"
	${DOCKER} ps
	exit 1
fi

CONTAINER_NAME=${CONTAINER_NAME:-OpenHD_ImageBuilder_work}
CONTINUE=${CONTINUE:-0}
PRESERVE_CONTAINER=${PRESERVE_CONTAINER:-0}

if [ -z "${IMG_NAME}" ]; then
	echo "IMG_NAME not set in 'config'" 1>&2
	echo 1>&2
exit 1
fi

# Ensure the Git Hash is recorded before entering the docker container
GIT_HASH=${GIT_HASH:-"$(git rev-parse HEAD)"}

CONTAINER_EXISTS=$(${DOCKER} ps -a --filter name="${CONTAINER_NAME}" -q)
CONTAINER_RUNNING=$(${DOCKER} ps --filter name="${CONTAINER_NAME}" -q)
if [ "${CONTAINER_RUNNING}" != "" ]; then
	echo "The build is already running in container ${CONTAINER_NAME}. Aborting."
	exit 1
fi
if [ "${CONTAINER_EXISTS}" != "" ] && [ "${CONTINUE}" != "1" ]; then
	echo "Container ${CONTAINER_NAME} already exists and you did not specify CONTINUE=1. Aborting."
	echo "You can delete the existing container like this:"
	echo "  ${DOCKER} rm -v ${CONTAINER_NAME}"
	exit 1
fi

# Modify original build-options to allow config file to be mounted in the docker container
BUILD_OPTS="$(echo "${BUILD_OPTS:-}" | sed -E 's@\-c\s?([^ ]+)@-c /config@')"

${DOCKER} build -t openhd_img_builder "${DIR}"
if [ "${CONTAINER_EXISTS}" != "" ]; then
	trap 'echo "got CTRL+C... please wait 5s" && ${DOCKER} stop -t 5 ${CONTAINER_NAME}_cont' SIGINT SIGTERM
	time ${DOCKER} run --rm --privileged \
		-e "GIT_HASH=${GIT_HASH}" \
		--volumes-from="${CONTAINER_NAME}" --name "${CONTAINER_NAME}_cont" \
		openhd_img_builder \
		bash -e -o pipefail -c "dpkg-reconfigure qemu-user-static &&
	cd /openhd_img_builder; ./build.sh ${BUILD_OPTS} &&
	rsync -av ${WORK_DIR}/*/build.log deploy/" &
	wait "$!"
else
	trap 'echo "got CTRL+C... please wait 5s" && ${DOCKER} stop -t 5 ${CONTAINER_NAME}' SIGINT SIGTERM
	time ${DOCKER} run --name "${CONTAINER_NAME}" --privileged \
		-e "GIT_HASH=${GIT_HASH}" \
		openhd_img_builder \
		bash -e -o pipefail -c "dpkg-reconfigure qemu-user-static &&
	cd /openhd_img_builder; ./build.sh ${BUILD_OPTS} &&
	rsync -av ${WORK_DIR}/*/build.log deploy/" &
	wait "$!"
fi
echo "copying results from deploy/"
${DOCKER} cp "${CONTAINER_NAME}":/openhd_img_builder/deploy .
ls -lah deploy

# cleanup
if [ "${PRESERVE_CONTAINER}" != "1" ]; then
	${DOCKER} rm -v "${CONTAINER_NAME}"
fi

echo "Done! Your image(s) should be in deploy/"

