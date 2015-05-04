# Copyright 1999-2015 Sabayon Linux
# Distributed under the terms of the GNU General Public License v2
#

EAPI=5
CMAKE_REQUIRED="never"
inherit eutils kde4-base

DESCRIPTION="Sabayon Linux Official KDE Artwork"
HOMEPAGE="http://www.sabayon.org/"
SRC_URI="mirror://sabayon/${CATEGORY}/${PN}/${PN}-${PVR}.tar.xz"
LICENSE="CCPL-Attribution-ShareAlike-3.0"
SLOT="0"
KEYWORDS="~amd64 ~arm ~x86"
IUSE="+ksplash"
RDEPEND=""

S="${WORKDIR}/${PN}"

src_install() {
	# KDM
	dodir ${KDEDIR}/share/apps/kdm/themes
	cd ${S}/kdm
	insinto ${KDEDIR}/share/apps/kdm/themes
	doins -r ./

	# Kwin
	dodir ${KDEDIR}/share/apps/aurorae/themes/
	cd ${S}/kwin
	insinto ${KDEDIR}/share/apps/aurorae/themes/
	doins -r ./

	# KSplash
	if use ksplash; then
		dodir ${KDEDIR}/share/apps/ksplash/Themes
		cd ${S}/ksplash
		insinto ${KDEDIR}/share/apps/ksplash/Themes
		doins -r ./
	fi
}
