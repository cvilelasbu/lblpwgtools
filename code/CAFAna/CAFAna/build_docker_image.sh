#!/bin/bash

DO_BUILD="0"
DO_RELEASE="1"
USE_GPERF="0"
DO_PUSH="0"
BASE_IMAGE="centos:latest"
TAGNAME="latest"

NCORES=8

IMAGE_NAME="${USER}/dune_cafana"
BRANCH_NAME="strong_and_stable"
REPO_URL="https://github.com/DUNE/lblpwgtools.git"

SCRIPTNAME=${0}

while [[ ${#} -gt 0 ]]; do

  key="$1"
  case $key in

      -f|--force-build)

      DO_BUILD="1"
      echo "[OPT]: Will rebuild container even if latest already exists."
      ;;

      -p|--push)

      DO_PUSH="1"
      echo "[OPT]: Will attempt to push to docker hub."
      ;;

      --use-gperftools)

      USE_GPERF="1"
      echo "[OPT]: Will compile in gperftools support."
      ;;

      -d|--debug)

      DO_RELEASE="0"
      echo "[OPT]: Will compile debug image type."
      ;;

      -j|--n-cores)

      if [[ ${#} -lt 2 ]]; then
        echo "[ERROR]: ${1} expected a value."
        exit 1
      fi

      NCORES="$2"
      echo "[OPT]: Will use \"${NCORES}\" cores."
      shift # past argument
      ;;

      -I|--image-name)

      if [[ ${#} -lt 2 ]]; then
        echo "[ERROR]: ${1} expected a value."
        exit 1
      fi

      IMAGE_NAME="$2"
      echo "[OPT]: Will name image: \"${IMAGE_NAME}\"."
      shift # past argument
      ;;

      -R|--repo-url)

      if [[ ${#} -lt 2 ]]; then
        echo "[ERROR]: ${1} expected a value."
        exit 1
      fi

      REPO_URL="$2"
      echo "[OPT]: Will build from repo: \"${REPO_URL}\"."
      shift # past argument
      ;;

      -B|--branch-name)

      if [[ ${#} -lt 2 ]]; then
        echo "[ERROR]: ${1} expected a value."
        exit 1
      fi

      BRANCH_NAME="$2"
      echo "[OPT]: Will build from branch: \"${BRANCH_NAME}\"."
      shift # past argument
      ;;

      -T|--tag-name)

      if [[ ${#} -lt 2 ]]; then
        echo "[ERROR]: ${1} expected a value."
        exit 1
      fi

      TAGNAME="$2"
      echo "[OPT]: Will tag image: \"${TAGNAME}\"."
      shift # past argument
      ;;

      -?|--help)
      echo "[RUNLIKE] ${SCRIPTNAME}"
      echo -e "\t-f|--force-build       : Will rebuild even if a latest image exists."
      echo -e "\t-d|--debug             : Compile with CMAKE_BUILD_TYPE=DEBUG"
      echo -e "\t-p|--push              : Attempt to push up to docker hub. Note you should have issued a docker login before running this script."
      echo -e "\t--use-gperftools       : Compile libunwind and gperftools"
      echo -e "\t-j|--n-cores           : Number of cores to pass to make install."
      echo -e "\t--base-image           : Base image to use (default: centos:latest)."
      echo -e "\t-I|--image-name        : Built image name (default: ${USER}/dune_cafana)."
      echo -e "\t-T|--tag-name          : Built/pushed tag name (default: latest)."
      echo -e "\t-R|--repo-url          : git repository to use (default: ${REPO_URL})."
      echo -e "\t-B|--branch-name       : Remote branch to use (default: ${BRANCH_NAME})."
      echo -e "\t-?|--help              : Print this message."
      exit 0
      ;;

      *)
              # unknown option
      echo "Unknown option $1"
      exit 1
      ;;
  esac
  shift # past argument or value
done


LATEST_EXISTS=$(sudo docker images -q ${IMAGE_NAME}:latest 2> /dev/null)

if [ "${LATEST_EXISTS}" == "" ] || [ "${DO_BUILD}" == "1" ]; then

  ROPT=""
  if [ "${DO_RELEASE}" == "1" ]; then
    ROPT="-r "
  fi

  GOPT=""
  if [ "${USE_GPERF}" == "1" ]; then
    GOPT="--use-gperftools "
  fi

  echo -e "#!/bin/bash\nyum install -y --setopt=tsflags=nodocs svn which make redhat-lsb-core glibc-devel automake libtool && yum clean all;cd /opt;source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh;git clone ${REPO_URL} lblpwgtools;cd lblpwgtools;git checkout ${BRANCH_NAME};cd code/CAFAna/CAFAna;./standalone_configure_and_build.sh -j ${NCORES} -u ${ROPT}${GOPT}-I /opt/CAFAna/; cat /build_scripts/CAFEnvWrapper.sh > /opt/CAFAna/CAFEnvWrapper.sh; chmod -R 775 /opt/CAFAna; rm -rf /opt/lblpwgtools; yum remove -y svn glibc-devel automake libtool && sudo yum autoremove && yum clean all;" > CAFBuildScript.sh
  echo -e '#!/bin/bash\nsource /opt/CAFAna/CAFAnaEnv.sh; echo "[CAFENV]: $@"; $@' > CAFEnvWrapper.sh

  sudo docker rm CAFAnaImageBuild_tmp

  sudo docker run --name CAFAnaImageBuild_tmp -v /cvmfs:/cvmfs:shared -v $(pwd):/build_scripts ${BASE_IMAGE} bash /build_scripts/CAFBuildScript.sh

  BRANCH_HEAD_REV=$(git ls-remote ${REPO_URL} | awk "/${BRANCH_NAME}/ {print \$1}" | cut -f 1 | cut -c-10)

  REV_TAG="${BRANCH_HEAD_REV}"
  if [ "${TAGNAME}" != "latest" ]; then
    REV_TAG="${BRANCH_HEAD_REV}_${TAGNAME}"
  fi

  sudo docker rmi ${USER}/dune_cafana:${TAGNAME}
  sudo docker commit CAFAnaImageBuild_tmp ${USER}/dune_cafana:${REV_TAG}
  sudo docker rmi ${USER}/dune_cafana:${TAGNAME}
  sudo docker commit CAFAnaImageBuild_tmp ${USER}/dune_cafana:${TAGNAME}

  sudo docker rm CAFAnaImageBuild_tmp

  if [ "${DO_PUSH}" == "1" ]; then
    echo "[INFO]: Pushing to docker hub..."
    sudo docker push ${USER}/dune_cafana:${REV_TAG}
    sudo docker push ${USER}/dune_cafana:${TAGNAME}
  fi
else
  echo "[INFO]: Image exists, rebuild not forced."
  if [ "${DO_PUSH}" == "1" ]; then
    echo "[INFO]: Pushing to docker hub..."
    sudo docker push ${USER}/dune_cafana:${TAGNAME}
  fi
fi