require 'formula'

class Vice < Formula
  homepage 'http://vice-emu.sourceforge.net/'
  url 'http://www.zimmers.net/anonftp/pub/cbm/crossplatform/emulators/VICE/vice-2.4.tar.gz'
  sha1 '719aa96cc72e7578983fadea1a31c21898362bc7'
  revision 1

  option 'with-sdl', 'Use SDL instead of Cocoa user interface'
  option 'with-memmap', 'Use memmap support (for monitor)'

  depends_on 'pkg-config' => :build
  depends_on 'jpeg'
  depends_on 'libpng'
  depends_on 'giflib' => :optional
  depends_on 'lame' => :optional
  depends_on 'sdl' if build.with? 'sdl'

  fails_with :llvm do
    build 2335
  end

  def install
    # Use Cocoa or SDL instead of X
    # Use a static lame, otherwise Vice is hard-coded to look in
    # /opt for the library.
    configure_options = [ "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--without-x",
                          "--enable-static-lame",
                          "--enable-sdlui",
                          "--enable-sdlsound",
                          "--enable-ethernet",
                          "--with-memmap",
                          # VICE can't compile against FFMPEG newer than 0.11:
                          # http://sourceforge.net/tracker/?func=detail&aid=3585471&group_id=223021&atid=1057617
                          "--disable-ffmpeg" ]

    inreplace 'configure' do |configure|
      configure.gsub! '/Library/Frameworks/SDL.framework/Headers', '/usr/local/include/SDL'
      configure.gsub! '-framework SDL', '-lSDL'
    end
    # Upstream forgot to point this to its new location?
    inreplace 'src/arch/sdl/archdep_unix.c', '#include "../unix/macosx/platform_macosx.c"', '#include "../../platform/platform_macosx.c"'

    system "./configure", *configure_options
    system "make"
    system "make bindist"
    prefix.install Dir['vice-macosx-*/*']
    bin.install_symlink Dir[prefix/'tools/*']
  end

  def caveats
    "Cocoa apps for these emulators have been installed to #{prefix}."
  end
end
