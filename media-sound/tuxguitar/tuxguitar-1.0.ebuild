# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=1
JAVA_PKG_IUSE="source"

inherit eutils java-pkg-2 java-ant-2 toolchain-funcs flag-o-matic fdo-mime gnome2-utils

MY_P="${PN}-src-${PV}"
DESCRIPTION="TuxGuitar is a multitrack guitar tablature editor and player written in Java-SWT"
HOMEPAGE="http://www.tuxguitar.com.ar/"
SRC_URI="mirror://sourceforge/${PN}/${MY_P}.tar.gz"
LICENSE="LGPL-2.1"
SLOT="0"
IUSE="alsa fluidsynth oss pdf"

# Test notes
# FTP plugin seems to connect but it doesn't list my files at FTP.
# Couldn't get JSA plugin working out of the box with IcedTea.

KEYWORDS="~amd64"
# FIXME: Are these X dependencies really needed to be here explicitly?
CDEPEND="dev-java/swt:3
	alsa? ( media-libs/alsa-lib )
	fluidsynth? ( media-sound/fluidsynth )
	pdf? ( dev-java/itext:0 )"
RDEPEND=">=virtual/jre-1.5
	alsa? ( media-sound/timidity++ )
	oss? ( media-sound/timidity++ )
	${CDEPEND}"

DEPEND=">=virtual/jdk-1.5
	${CDEPEND}"

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	if ! built_with_use 'dev-java/swt' 'cairo'; then
		eerror "You must build dev-java/swt with cairo support"
		die "dev-java/swt built without cairo"
	fi
	java-pkg-2_pkg_setup
}

src_unpack() {
	unpack ${A}
	cd "${S}"/TuxGuitar/lib || die
	java-pkg_jar-from swt-3
}

src_compile() {
	if use pdf; then
		echo "" >> TuxGuitar-pdf/build.properties || die
		echo "path.itext=$(java-pkg_getjar itext iText.jar)" >> TuxGuitar-pdf/build.properties || die "Error adding itext path"
		echo "path.swt=$(java-pkg_getjar swt-3 swt.jar)" >> TuxGuitar-pdf/build.properties || die "Error adding swt path"
	fi
	cd TuxGuitar || die "cd failed"
	eant all
	for plugin in $(list_plugins); do
		plugin_compile $plugin
	done
}

src_install() {
	cd TuxGuitar || die "cd failed"
	java-pkg_dojar tuxguitar.jar
	use source && java-pkg_dosrc src/org
	# TODO: Decide if plugin sources should be installed
	java-pkg_dolauncher ${PN} \
		--main org.herac.tuxguitar.gui.TGMain \
		--java_args "-Xms128m -Xmx128m"
	# Images and Files
	insinto /usr/share/${PN}/lib
	doins -r share || die "doins failed"
	java-pkg_sointo /usr/share/${PN}/lib/lib
	for plugin in $(list_plugins); do
		plugin_install $plugin
	done
	doman "${S}/misc/${PN}.1" || die "doman failed"
	insinto /usr/share/mime/packages
	doins "${S}/misc/${PN}.xml"
	doicon "${S}/misc/${PN}.xpm" || die "doicon failed"
	domenu "${S}/misc/${PN}.desktop" || die "domenu failed"
}

plugin_compile() {
	cd "${S}"/TuxGuitar-${1} || die
	eant all
	if [[ -d jni ]]; then
		append-flags $(java-pkg_get-jni-cflags)
		cd jni || die "\"cd jni\" failed"
		CC=$(tc-getCC) emake || die "emake failed"
	fi
}

plugin_install() {
	cd "${S}"/TuxGuitar-${1} || die
	local TUXGUITAR_INST_PATH=/usr/share/${PN}/lib
	local BINARY_NAME=tuxguitar-${1}
	insinto ${TUXGUITAR_INST_PATH}/share/plugins
	doins ${BINARY_NAME}.jar || die "doins ${BINARY_NAME}.jar failed"
	#TuxGuitar has its own classloader. No need to register the plugins.
	if [[ -d jni ]]; then
		java-pkg_doso jni/lib${BINARY_NAME}-jni.so
	fi
}

#Return list of plugins to compile/install
#Removed FTP plugin from list as it's not working now.
#Check to see if it's working while bumping. 
list_plugins() {
	echo \
		$(usev alsa) ascii compat converter $(usev fluidsynth) gtp \
		jsa lilypond midi musicxml $(usev oss) $(usev pdf) ptb tef tray
}

pkg_postinst() {
	fdo-mime_desktop_database_update
	gnome2_icon_cache_update
	if use fluidsynth; then
		ewarn "Fluidsynth plugin blocks behavior of JSA plugin."
		ewarn "Enable only one of them in \"Tools > Plugins\""
	fi
}

pkg_postrm() {
	fdo-mime_desktop_database_update
	gnome2_icon_cache_update
}
