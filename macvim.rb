require 'formula'

# Reference: https://github.com/b4winckler/macvim/wiki/building
class Macvim < Formula
  homepage 'http://code.google.com/p/macvim/'
  url 'https://github.com/b4winckler/macvim/archive/snapshot-73.tar.gz'
  version '7.4-73'
  sha1 'b87e37fecb305a99bc268becca39f8854e3ff9f0'
  revision 1

  head 'https://github.com/b4winckler/macvim.git', :branch => 'master'

  option "custom-icons", "Try to generate custom document icons"
  option "override-system-vim", "Override system vim"
  option "with-breakindent-patch", "Build with breakindent patch."

  def patches
    if build.with? 'breakindent-patch'
      { :p1 => 'https://gist.github.com/echristopherson/6217376/raw/4a023374dc61116c08cd7762c20489e1c2da237f/vim-7.3.944-fc17-modified-breakindent.patch' }
    end
  end

  depends_on :xcode => :build
  depends_on 'cscope' => :recommended
  depends_on 'lua' => :optional
  depends_on 'luajit' => :optional
  depends_on :python => :recommended
  depends_on :python3 => :optional

  env :std if MacOS.version <= :snow_leopard
  # Help us! We'd like to use superenv in these environments too

  def install
    # MacVim doesn't have and required any Python package, unset PYTHONPATH.
    ENV.delete('PYTHONPATH')

    # Set ARCHFLAGS so the Python app (with C extension) that is
    # used to create the custom icons will not try to compile in
    # PPC support (which isn't needed in Homebrew-supported systems.)
    ENV['ARCHFLAGS'] = "-arch #{MacOS.preferred_arch}"

    # If building for 10.7 or up, make sure that CC is set to "clang".
    ENV.clang if MacOS.version >= :lion

    # macvim only works with the current Ruby.framework because it builds with -framework Ruby
    system_ruby = "/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby"

    args = %W[
      --with-features=huge
      --enable-multibyte
      --with-macarchs=#{MacOS.preferred_arch}
      --enable-perlinterp
      --enable-rubyinterp
      --enable-tclinterp
      --with-ruby-command=#{system_ruby}
      --with-tlib=ncurses
      --with-compiledby=Homebrew
      --with-local-dir=#{HOMEBREW_PREFIX}
    ]

    args << "--enable-cscope" if build.with? "cscope"

    if build.with? "lua"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    if build.with? "luajit"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
      args << "--with-luajit"
    end

    # only allow either python or python3; if the optional
    # python3 is chosen, default to it, otherwise use python2
    if build.with? "python3"
      args << "--enable-python3interp"
    elsif build.with? "python"
      ENV.prepend "LDFLAGS", `python-config --ldflags`.chomp
      ENV.prepend "CFLAGS", `python-config --cflags`.chomp
      args << "--enable-pythoninterp"
    end

    # configure appends "SDKS/..." to the value of `xcode-select -print-path`,
    # but this isn't correct on recent Xcode, so we need to set it manually.
    # FIXME this is a bug, and it should be fixed upstream.
    unless MacOS::CLT.installed?
      args << "--with-developer-dir=#{MacOS::Xcode.prefix}/Platforms/MacOSX.platform/Developer"
      args << "--with-macsdk=#{MacOS.version}"
    end

    system "./configure", *args

    if build.include? "custom-icons"
      # Get the custom font used by the icons
      system "make", "-C", "src/MacVim/icons", "getenvy"
    else
      # Building custom icons fails for many users, so off by default.
      inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
      inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
                                 "VIM_APP_DIR=#{prefix}"
    bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    executables = %w[mvimdiff mview mvimex gvim gvimdiff gview gvimex]
    executables += %w[vi vim vimdiff view vimex] if build.include? "override-system-vim"
    executables.each { |e| bin.install_symlink "mvim" => e }
  end

  def caveats
    if build.with? "python" and build.with? "python3"
      <<-EOS.undent
        MacVim can no longer be brewed with dynamic support for both Python versions.
        Only Python 3 support has been provided.
      EOS
    end
  end

  test do
    # Simple test to check if MacVim was linked to Python version in $PATH
    if build.with? "python"
      vim_path = prefix/"MacVim.app/Contents/MacOS/Vim"

      # Get linked framework using otool
      otool_output = `otool -L #{vim_path} | grep -m 1 Python`.gsub(/\(.*\)/, "").strip.chomp

      # Expand the link and get the python exec path
      vim_framework_path = Pathname.new(otool_output).realpath.dirname.to_s.chomp
      system_framework_path = `python-config --exec-prefix`.chomp

      assert_equal system_framework_path, vim_framework_path
    end
  end
end
