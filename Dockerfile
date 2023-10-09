FROM debian:bookworm

WORKDIR /home
SHELL ["/bin/bash", "-c"]

ENV ANDROID_SDK_ROOT=/home/android-sdk \
    NDK_ROOT=/home/android-sdk/ndk/25.2.9519653

# install jdk
RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update && apt-get install --yes --no-install-recommends \
       default-jdk \
    && rm -rf /var/lib/apt/lists/*

RUN set -o errexit -o nounset \
    && echo "Testing Java installation" \
    && java --version

# install sdkmanager
ARG SDKMANAGER_DOWNLOAD_SHA256=8919e8752979db73d8321e9babe2caedcc393750817c1a5f56c128ec442fb540
RUN set -o errexit -o nounset \
    && apt-get update && apt-get install --yes --no-install-recommends \
       wget \
       unzip \
       make \
       git \
       ninja-build \
    && rm --recursive --force /var/lib/apt/lists/* \
    \
    && echo "Testing VCSes" \
    && which wget \
    && which unzip \
    && which make \
    && which git \
    && which ninja \
    \
    && echo "Downloading sdkmanager" \
    && wget --no-verbose --output-document=commandlinetools.zip "https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip" \
    && echo "Checking Sdkmanager download hash" \
    && echo "${SDKMANAGER_DOWNLOAD_SHA256} *commandlinetools.zip" | sha256sum --check - \
    \
    && echo "install sdkmanager" \
    && unzip commandlinetools.zip && mkdir android-sdk && mv cmdline-tools android-sdk \
    && cd /home/android-sdk/cmdline-tools && mkdir latest \
    && cd /home/android-sdk/cmdline-tools && mv lib latest/ \
    && cd /home/android-sdk/cmdline-tools && mv bin latest/ \ 
    && cd /home/android-sdk/cmdline-tools && mv NOTICE.txt latest/ \
    && cd /home/android-sdk/cmdline-tools && mv source.properties latest/ \
    && ln --symbolic "/home/android-sdk/cmdline-tools/latest/bin/sdkmanager" /usr/bin/sdkmanager
 
RUN set -o errexit -o nounset \
    && echo "Testing sdkmanager installation" \
    && sdkmanager --version

# install ndk cmake build-tools
RUN set -o errexit -o nounset \
    && yes | sdkmanager --licenses \
    && sdkmanager "cmake;3.18.1" \
    && ln --symbolic "$ANDROID_SDK_ROOT/cmake/3.18.1/bin/cmake" /usr/bin/cmake \
    && sdkmanager "ndk;25.2.9519653" \
    && sdkmanager "build-tools;28.0.3" \
    && ln --symbolic "$ANDROID_SDK_ROOT/build-tools/28.0.3/dx" /usr/bin/dx

# install gradle 7.6.2
ENV GRADLE_VERSION 7.6.2
ARG GRADLE_DOWNLOAD_SHA256=a01b6587e15fe7ed120a0ee299c25982a1eee045abd6a9dd5e216b2f628ef9ac
RUN set -o errexit -o nounset \
    && echo "Downloading Gradle" \
    && wget --no-verbose --output-document=gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    \
    && echo "Checking Gradle download hash" \
    && echo "${GRADLE_DOWNLOAD_SHA256} *gradle.zip" | sha256sum --check - \
    \
    && echo "Installing Gradle" \
    && unzip gradle.zip \
    && rm gradle.zip \
    && ln --symbolic "/home/gradle-7.6.2/bin/gradle" /usr/bin/gradle

RUN set -o errexit -o nounset \
    && echo "Testing Gradle installation" \
    && gradle --version

VOLUME ["/home/project"]

# build shell
RUN set -o errexit -o nounset \
    && mkdir project \
    && echo -e '#!/bin/bash \ncd project && gradle wrapper && ./gradlew clean makeJar && dx --dex --output=monkeyq.jar monkey/build/libs/monkey.jar && echo "monkey.jar编译成功" && sh ./build_native.sh && echo "so包编译成功，在libs内查看"' > build.sh \
    && chmod +x build.sh

ENTRYPOINT ["bash"]

# build images run
# docker build -t gradle . 
# docker run --name gradle -it --rm  -v ./Fastbot_Android:/home/project gradle
