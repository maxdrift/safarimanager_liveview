#!/bin/bash
set -e pipefail

main() {
  # imagemagick_vsn="${imagemagick_vsn:-20.1.0}"
  imagemagick_vsn="${imagemagick_vsn:-7.1.0-49}"

  mkdir -p tmp/cache

  cache_dir="$PWD/tmp/cache"
  imagemagick_dir="${cache_dir}/ImageMagick-${imagemagick_vsn}"
  # if [ ! -d "${imagemagick_dir}" ]; then
    build_imagemagick $imagemagick_vsn $cache_dir
  # fi

  # export MAGICK_HOME="${imagemagick_dir}/ImageMagick-7.0.10"
  # export PATH="$MAGICK_HOME/bin:$PATH"
  # export DYLD_LIBRARY_PATH="$MAGICK_HOME/lib/"
  # export DISPLAY=:0
  echo "checking Imagemagick"
  magick logo: logo.gif
  identify logo.gif
  echo "Imagemagick ok"
  rm -f logo.gif
}

# build_imagemagick $vsn $dest_dir
build_imagemagick() {
  vsn=$1
  dest_dir=$2

  cd tmp
  url=https://imagemagick.org/archive/ImageMagick-${vsn}.tar.gz
  # curl --fail -LO $url
  # tar -xvzf ImageMagick-${vsn}.tar.gz -C $dest_dir
  cd $dest_dir/ImageMagick-${vsn}
  ./configure
  make
  rm -f ImageMagick-${vsn}.tar.gz
  cd - > /dev/null
}

# # build_imagemagick $vsn $dest_dir
# build_imagemagick() {
#   vsn=$1
#   dest_dir=$2

#   cd tmp
#   url=https://imagemagick.org/archive/binaries/ImageMagick-x86_64-apple-darwin${vsn}.tar.gz
#   curl --fail -LO $url
#   mkdir -p $dest_dir
#   tar -xvzf ImageMagick-x86_64-apple-darwin${vsn}.tar.gz -C $dest_dir
#   rm -f ImageMagick-x86_64-apple-darwin${vsn}.tar.gz
#   cd - > /dev/null
# }

main
