# ============================================================
#  furnizsh — Homebrew formula
#
#  Lives in the tap repo (Wosmos/homebrew-tap) as Formula/furnizsh.rb.
#  This copy is the source of truth; the release workflow copies it across
#  with the version and sha256 substituted.
#
#      brew tap wosmos/tap
#      brew install furnizsh
#      furnizsh install
#
#  The formula deliberately does NOT run the installer. Homebrew formulae
#  must not write to $HOME during `brew install` — setting up your shell is
#  your call, made explicitly by running `furnizsh install`.
#
#  No dependencies: the scripts are POSIX-ish bash that runs fine on the
#  bash 3.2 macOS ships, and the tools furnizsh installs for you are
#  chosen at run time by `--tools`, not baked in here.
# ============================================================

class Furnizsh < Formula
  desc "Neon terminal in one command - Ghostty, zsh, Starship, 4 themes, 24 commands"
  homepage "https://wosmos.github.io/furnizsh"
  url "https://github.com/Wosmos/furnizsh/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256"
  license "MIT"
  head "https://github.com/Wosmos/furnizsh.git", branch: "main"

  def install
    # The payload: configs, themes, and the scripts the dispatcher calls.
    pkgshare.install "config", "extras", "install.sh", "uninstall.sh",
                     "doctor.sh", "update.sh", "VERSION"

    # The dispatcher itself lives in libexec, and bin/furnizsh becomes a
    # wrapper that hands it FURNIZSH_SHARE. Without this the script has to
    # guess its prefix; here we know it exactly.
    libexec.install "bin/furnizsh"
    (bin/"furnizsh").write_env_script libexec/"furnizsh",
                                       FURNIZSH_SHARE: pkgshare

    doc.install "README.md", "CHANGELOG.md"
    doc.install Dir["docs/*.md"]
  end

  def caveats
    <<~EOS
      furnizsh is installed but has not changed anything yet.

      To set up your terminal:
        furnizsh install --dry-run    # see exactly what it would do
        furnizsh install

      Then open a new terminal:
        agdoctor      verify every part of the setup
        cheatsheet    the reference card
        theme         list themes, or switch

      To remove it later:
        furnizsh uninstall
    EOS
  end

  test do
    # The dispatcher must find its payload and report the packaged version.
    assert_match version.to_s, shell_output("#{bin}/furnizsh version")

    # Help must work without touching the filesystem.
    assert_match "a neon terminal", shell_output("#{bin}/furnizsh help")

    # Every theme the tap ships must be listed.
    themes = shell_output("#{bin}/furnizsh theme")
    %w[neon catppuccin gruvbox tokyonight].each { |t| assert_match t, themes }

    # And --dry-run must genuinely change nothing.
    ENV["HOME"] = testpath
    output = shell_output("#{bin}/furnizsh install --dry-run --tools core")
    assert_match "DRY RUN", output
    refute_predicate testpath/".config/furnizsh", :exist?
  end
end
