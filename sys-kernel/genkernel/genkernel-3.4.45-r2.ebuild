# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

# genkernel-9999        -> latest Git branch "master"
# genkernel-VERSION     -> normal genkernel release

EAPI="3"

VERSION_BUSYBOX='1.20.2'
VERSION_FUSE='2.8.6'
VERSION_ISCSI='2.0-872'
VERSION_UNIONFS_FUSE='0.24'
VERSION_GPG='1.4.11'

RH_HOME="ftp://sources.redhat.com/pub"
BB_HOME="http://www.busybox.net/downloads"

COMMON_URI="
		${BB_HOME}/busybox-${VERSION_BUSYBOX}.tar.bz2
		http://www.open-iscsi.org/bits/open-iscsi-${VERSION_ISCSI}.tar.gz
		mirror://sourceforge/fuse/fuse-${VERSION_FUSE}.tar.gz
		http://podgorny.cz/unionfs-fuse/releases/unionfs-fuse-${VERSION_UNIONFS_FUSE}.tar.bz2
		mirror://gnupg/gnupg/gnupg-${VERSION_GPG}.tar.bz2"

if [[ ${PV} == 9999* ]]
then
	EGIT_REPO_URI="git://git.overlays.gentoo.org/proj/${PN}.git
		http://git.overlays.gentoo.org/gitroot/proj/${PN}.git"
	inherit git-2 bash-completion-r1 eutils
	S="${WORKDIR}/${PN}"
	SRC_URI="${COMMON_URI}"
	KEYWORDS=""
else
	inherit bash-completion-r1 eutils
	SRC_URI="mirror://gentoo/${P}.tar.bz2
		${COMMON_URI}"
	KEYWORDS="alpha amd64 arm hppa ia64 ~mips ppc ppc64 s390 sparc x86"
fi

DESCRIPTION="Gentoo automatic kernel building scripts"
HOMEPAGE="http://www.gentoo.org"

LICENSE="GPL-2"
SLOT="0"
RESTRICT=""
IUSE="crypt cryptsetup ibm selinux"  # Keep 'crypt' in to keep 'use crypt' below working!

DEPEND="sys-fs/e2fsprogs
	selinux? ( sys-libs/libselinux )"
RDEPEND="${DEPEND}
		cryptsetup? ( sys-fs/cryptsetup )
		app-arch/cpio
		>=app-misc/pax-utils-0.2.1
		!<sys-apps/openrc-0.9.9
		sys-fs/dmraid
		sys-fs/lvm2"
# pax-utils is used for lddtree

if [[ ${PV} == 9999* ]]; then
	DEPEND="${DEPEND} app-text/asciidoc"
fi

src_unpack() {
	if [[ ${PV} == 9999* ]] ; then
		git-2_src_unpack
	else
		unpack ${P}.tar.bz2
	fi
}

src_prepare() {
	use selinux && sed -i 's/###//g' "${S}"/gen_compile.sh

	epatch "${FILESDIR}"/${PN}-crypt-config-5.patch
	# Sabayon Bug 2836, can be upstreamed
	epatch "${FILESDIR}"/${PN}-virtio-support-bug-2836-3.patch

	# Backport some git patches
	epatch "${FILESDIR}"/backports/*.patch
	# Add some more improvements that ease debugging
	epatch "${FILESDIR}"/debug-improvements/*.patch
	# Add systemd-udev support as device manager
	epatch "${FILESDIR}"/0003-genkernel-add-simple-udev-support-include-udev-into-.patch
	epatch "${FILESDIR}"/0004-gen_compile-use-LVM-from-system-for-the-initramfs.patch
	epatch "${FILESDIR}"/0005-gen_compile-use-DMRAID-from-system-don-t-compile-our.patch
	epatch "${FILESDIR}"/0006-gen_compile-use-MDADM-from-system.patch

	# Update software.sh
	sed -i \
		-e "s:VERSION_BUSYBOX:$VERSION_BUSYBOX:" \
		-e "s:VERSION_FUSE:$VERSION_FUSE:" \
		-e "s:VERSION_ISCSI:$VERSION_ISCSI:" \
		-e "s:VERSION_UNIONFS_FUSE:$VERSION_UNIONFS_FUSE:" \
		-e "s:VERSION_GPG:$VERSION_GPG:" \
		"${S}"/defaults/software.sh \
		|| die "Could not adjust versions"
}

src_compile() {
	if [[ ${PV} == 9999* ]]; then
		emake || die
	fi
}

src_install() {
	insinto /etc
	doins "${S}"/genkernel.conf || die "doins genkernel.conf"

	doman genkernel.8 || die "doman"
	dodoc AUTHORS ChangeLog README TODO || die "dodoc"

	dobin genkernel || die "dobin genkernel"

	rm -f genkernel genkernel.8 AUTHORS ChangeLog README TODO genkernel.conf

	insinto /usr/share/genkernel
	doins -r "${S}"/* || die "doins"
	use ibm && cp "${S}"/ppc64/kernel-2.6-pSeries "${S}"/ppc64/kernel-2.6 || \
		cp "${S}"/arch/ppc64/kernel-2.6.g5 "${S}"/arch/ppc64/kernel-2.6

	# Copy files to /var/cache/genkernel/src
	elog "Copying files to /var/cache/genkernel/src..."
	mkdir -p "${D}"/var/cache/genkernel/src
	cp -f \
		"${DISTDIR}"/busybox-${VERSION_BUSYBOX}.tar.bz2 \
		"${DISTDIR}"/fuse-${VERSION_FUSE}.tar.gz \
		"${DISTDIR}"/unionfs-fuse-${VERSION_UNIONFS_FUSE}.tar.bz2 \
		"${DISTDIR}"/gnupg-${VERSION_GPG}.tar.bz2 \
		"${DISTDIR}"/open-iscsi-${VERSION_ISCSI}.tar.gz \
		"${D}"/var/cache/genkernel/src || die "Copying distfiles..."

	newbashcomp "${FILESDIR}"/genkernel.bash "${PN}"
	insinto /etc
	doins "${FILESDIR}"/initramfs.mounts
}

pkg_postinst() {
	echo
	elog 'Documentation is available in the genkernel manual page'
	elog 'as well as the following URL:'
	echo
	elog 'http://www.gentoo.org/doc/en/genkernel.xml'
	echo
	ewarn "This package is known to not work with reiser4.  If you are running"
	ewarn "reiser4 and have a problem, do not file a bug.  We know it does not"
	ewarn "work and we don't plan on fixing it since reiser4 is the one that is"
	ewarn "broken in this regard.  Try using a sane filesystem like ext3 or"
	ewarn "even reiser3."
	echo
	ewarn "The LUKS support has changed from versions prior to 3.4.4.  Now,"
	ewarn "you use crypt_root=/dev/blah instead of real_root=luks:/dev/blah."
	echo
	if use crypt && ! use cryptsetup ; then
		ewarn "Local use flag 'crypt' has been renamed to 'cryptsetup' (bug #414523)."
		ewarn "Please set flag 'cryptsetup' for this very package if you would like"
		ewarn "to have genkernel create an initramfs with LUKS support."
		ewarn "Sorry for the inconvenience."
		echo
	fi
}
