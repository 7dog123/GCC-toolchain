#!/bin/sh

# Exit with code 1 when any command executed returns a non-zero exit code.
onerr()
{
   exit 1;
}
trap onerr ERR

## Determine the maximum number of processes that Make can work with.
PROC_NR=$(getconf _NPROCESSORS_ONLN)

TARGET_ALIAS="x86_64-pc-linux-gnu"
TARG_XTRA_OPTS=""
TARGET_PREFIX="/usr/local/cross-tools"

## Download texinfo source code
#REPO_URL="https://github.com/debian-tex/texinfo"
#REPO_FOLDER="texinfo"
#BRANCH_NAME="upstream/7.0.3"
#if test ! -d "$REPO_FOLDER"; then
#  git clone --depth 1 -b "$BRANCH_NAME" "$REPO_URL"
#else
#  git -C "$REPO_FOLDER" fetch origin
#  git -C "$REPO_FOLDER" reset --hard "origin/${BRANCH_NAME}"
#  git -C "$REPO_FOLDER" checkout "$BRANCH_NAME"
#fi
#cd "$REPO_FOLDER"

#autopoint -V 0.21.1 --force

## For each target
#for TARGET in "$TARGET_ALIAS"; do
#	## Create and ente the toolchain/build directory
#	rm -rf "build-$TARGET"
#   mkdir "build-$TARGET"
#    cd "build-$TARGET"
#	
#	../configure \
#	--prefix=/usr \
#	--with-libiconv-prefix=no \
#	--with-libintl-prefix=no \
#	--enable-perl-xs \
#	$TARG_XTRA_OPTS
#	
	# Compile and install
#	make -j "$PROC_NR"
#	make  -j "$PROC_NR" install
#	make  -j "$PROC_NR" TEXMF=/usr/share/texmf install-tex
#	make  -j "$PROC_NR" clean
#	
#	pushd /usr/share/info
#       rm -v dir
#        for f in *
#       do install-info $f dir 2>/dev/null
#      done
#     popd
#	
	## Exit the build directory
#	cd ../..
#	
	## End target.
#done

## Download binutils source code
REPO_URL="https://github.com/bminor/binutils-gdb"
REPO_FOLDER="binutils-gdb"
BRANCH_NAME="binutils-2_40"
if test ! -d "$REPO_FOLDER"; then
  git clone --depth 1 -b "$BRANCH_NAME" "$REPO_URL"
else
  git -C "$REPO_FOLDER" fetch origin
  git -C "$REPO_FOLDER" reset --hard "origin/${BRANCH_NAME}"
  git -C "$REPO_FOLDER" checkout "$BRANCH_NAME"
fi
cd "$REPO_FOLDER"

patch -Np1 -i ../patches/preserve-timestamps.patch
patch -Np1 -i ../patches/makeinfo.patch

rm -rf gas/doc/.dirstamp

## For each target
for TARGET in "$TARGET_ALIAS"; do
	## Create and ente the toolchain/build directory
	rm -rf "build-$TARGET"
    mkdir "build-$TARGET"
    cd "build-$TARGET"
	
	# Configure x86_64-pc-linux-gnu binutils stage 1
	../configure \
	--quiet \
	--prefix="$TARGET_PREFIX" \
	--target="$TARGET" \
	--with-sysroot="$TARGET_PREFIX"/"$TARGET" \
	--disable-nls \
	--enable-gprofng=no \
	--disable-werror \
	--with-gmp="C:\cygwin64\usr\include" \
	--with-mpfr="C:\cygwin64\usr\include" \
	$TARG_XTRA_OPTS
	
	# Compile and install
	make --quiet -j "$PROC_NR"
	make --quiet -j "$PROC_NR" install
	make --quiet -j "$PROC_NR" clean
	
	## Exit the build directory
	cd ../..
	
	## End target.
done

## Download gcc source code
REPO_URL="https://github.com/gcc-mirror/gcc"
REPO_FOLDER="gcc"
BRANCH_NAME="releases/gcc-12.2.0"
if test ! -d "$REPO_FOLDER"; then
  git clone --depth 1 -b "$BRANCH_NAME" "$REPO_URL"
else
  git -C "$REPO_FOLDER" fetch origin
  git -C "$REPO_FOLDER" reset --hard "origin/${BRANCH_NAME}"
  git -C "$REPO_FOLDER" checkout "$BRANCH_NAME"
fi
cd "$REPO_FOLDER"

## On x86_64 hosts, set the default directory name for 64-bit libraries to “lib”: 
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

## As in the first build of GCC, the GMP, MPFR, and MPC packages are required. Unpack the tarballs and move them into the required directories
./contrib/download_prerequisites

## For each target
for TARGET in "$TARGET_ALIAS"; do
	## Create and ente the toolchain/build directory
	rm -rf "build-$TARGET"
    mkdir "build-$TARGET"
    cd "build-$TARGET"
	
	# Configure x86_64-pc-linux-gnu gcc stage 1
	../configure \
	--quiet \
	--prefix="$TARGET_PREFIX" \
	--target="$TARGET" \
	--with-sysroot="$TARGET_PREFIX"/"$TARGET" \
	--with-glibc-version=2.37 \
	--with-newlib \
	--without-headers \
	--enable-default=pie \
	--enable-default-ssp \
	--disable-nls \
	--disable-shared \
	--disable-multilib \
	--disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
	--enable-languages=c,c++ \
	$TARG_XTRA_OPTS
	
	# Compile and install
	make --quiet -j "$PROC_NR"
	make --quiet -j "$PROC_NR" install
	
	## Exit the build directory
	cd ..
	
	## This build of GCC has installed a couple of internal system headers. Normally one of them, limits.h, would in turn include the corresponding system limits.h 
	## header, in this case, "$TARGET_PREFIX"/include/limits.h. However, at the time of this build of GCC "$TARGET_PREFIX"/include/limits.h does not exist, so the internal header that has 
	## just been installed is a partial, self-contained file and does not include the extended features of the system header. This is adequate for building Glibc, but the 
	## full internal header will be needed later. Create a full version of the internal header using a command that is identical to what the GCC build system does in
	## normal circumstances

	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $("$TARGET"-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
	
	pushd "build-$TARGET"
	make --quiet -j "$PROC_NR" clean
	popd
	
	## End target.
	cd ..
done

## Download linux api source code
REPO_URL="https://github.com/torvalds/linux"
REPO_FOLDER="linux"
BRANCH_NAME="v6.2"
if test ! -d "$REPO_FOLDER"; then
  git clone --depth 1 -b "$BRANCH_NAME" "$REPO_URL"
else
  git -C "$REPO_FOLDER" fetch origin
  git -C "$REPO_FOLDER" reset --hard "origin/${BRANCH_NAME}"
  git -C "$REPO_FOLDER" checkout "$BRANCH_NAME"
fi
cd "$REPO_FOLDER"

## Determine the maximum number of processes that Make can work with.
PROC_NR=$(getconf _NPROCESSORS_ONLN)

## For each target
for TARGET in "$TARGET_ALIAS"; do
	
	# compile and install Linux API Headers
	make -j "$PROC_NR" mrproper
	make -j "$PROC_NR" headers
	find usr/include -type f ! -name '*.h' -delete
	cp -rv usr/include "$TARGET_PREFIX"
	
	cd ../
done

## Download glibc source code
REPO_URL="https://github.com/bminor/glibc"
REPO_FOLDER="glibc"
BRANCH_NAME="glibc-2.37"

if test ! -d "$REPO_FOLDER"; then
  git clone --depth 1 -b "$BRANCH_NAME" "$REPO_URL"
else
  git -C "$REPO_FOLDER" fetch origin
  git -C "$REPO_FOLDER" reset --hard "origin/${BRANCH_NAME}"
  git -C "$REPO_FOLDER" checkout "$BRANCH_NAME"
fi
cd "$REPO_FOLDER"

## First, create a symbolic link for LSB compliance. Additionally, for x86_64, create a compatibility symbolic link required for proper operation of the dynamic
## library loader 
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 "$TARGET_PREFIX"/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 "$TARGET_PREFIX"/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 "$TARGET_PREFIX"/lib64/ld-lsb-x86-64.so.3
    ;;
esac

## Some of the Glibc programs use the non-FHS-compliant /var/db directory to store their runtime data. Apply the following patch to make such programs store
## their runtime data in the FHS-compliant locations

patch -Np1 -i ../patches/glibc-2.37-fhs-1.patch

## For each target
for TARGET in "$TARGET_ALIAS"; do
	## Create and ente the toolchain/build directory
	rm -rf "build-$TARGET"
    mkdir "build-$TARGET"
    cd "build-$TARGET"
	
	# Configure x86_64-pc-linux-gnu glibc
	echo "rootsbindir=/usr/sbin" > configparms
	../configure \
	--quiet \
	--prefix="$TARGET_PREFIX" \
	--host=x86_64-pc-linux-gnu \
	--build=x86_64-pc-cygwin \
	--target="$TARGET" \
	--enable-kernel=3.2                \
    --with-headers="$TARGET_PREFIX"/include    \
    libc_cv_slibdir="$TARGET_PREFIX"/lib \
	$TARG_XTRA_OPTS
	
	## Compile and install.
    make --quiet -j "$PROC_NR"
    make --quiet -j "$PROC_NR" DESTDIR="$TARGET_PREFIX" install
    make --quiet -j "$PROC_NR" clean
	
	## Fix a hard coded path to the executable loader in the ldd script
	sed '/RTLDLIST=/s@/usr@@g' -i "$TARGET_PREFIX"/bin/ldd
	
	## Now that our cross-toolchain is complete, finalize the installation of the limits.h header. To do this, run a utility provided by the GCC developers
	"$TARGET_PREFIX"/libexec/gcc/"$TARGET_ALIAS"/12.2.0/install-tools/mkheaders
	
    ## Exit the build directory
	cd ../..
	
	## End target.
done

## Download gcc source code
#REPO_URL="https://github.com/gcc-mirror/gcc"
REPO_FOLDER="gcc"
#BRANCH_NAME="releases/gcc-12.2.0"
#if test ! -d "$REPO_FOLDER"; then
  #git clone --depth 1 -b "$BRANCH_NAME" "$REPO_URL"
#else
  #git -C "$REPO_FOLDER" fetch origin
  #git -C "$REPO_FOLDER" reset --hard "origin/${BRANCH_NAME}"
  #git -C "$REPO_FOLDER" checkout "$BRANCH_NAME"
#fi
cd "$REPO_FOLDER"


for TARGET in "$TARGET_ALIAS"; do
	## Create and ente the toolchain/build directory
	rm -rf "build-libstdc++-$TARGET"
    mkdir "build-libstdc++-$TARGET"
    cd "build-libstdc++-$TARGET"
	
	# Configure libstdc++
	../configure \
	--quiet \
	--prefix="$TARGET_PREFIX" \
	--target="$TARGET" \
	--disable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch         \
    --with-gxx-include-dir="$TARGET_PREFIX"/"$TARGET"/include/c++/12.2.0
	$TARG_XTRA_OPTS
	
	# Compile and install
	make --quiet -j "$PROC_NR"
	make --quiet -j "$PROC_NR" DESTDIR="$TARGET_PREFIX" install
	make --quiet -j "$PROC_NR" clean
	
	## Remove the libtool archive files because they are harmful for cross-compilation
	rm -v "$TARGET_PREFIX"/lib/lib{stdc++,stdc++fs,supc++}.la
	
	## Exit the build directory
	cd ../..
	
	## End target.
done

