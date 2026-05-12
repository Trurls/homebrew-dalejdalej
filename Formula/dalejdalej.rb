class Dalejdalej < Formula
  desc "Monitor GitHub PRs with Claude AI — auto-rebase and CI triage"
  homepage "https://github.com/Trurls/homebrew-dalejdalej"
  url "https://github.com/Trurls/homebrew-dalejdalej/archive/refs/tags/v0.0.8.tar.gz"
  sha256 "cae39707d088f2fd0d4f933e2bf62bc121ac214f75719ecf9788a4def72da703"
  license "MIT"
  head "ssh://git@github-personal/Trurls/homebrew-dalejdalej.git", branch: "main"

  depends_on "fzf"
  depends_on "jq"
  depends_on "yq"

  def install
    bin.install "bin/dalejdalej"
    libexec.install Dir["libexec/*"]
    chmod 0755, Dir[libexec/"*.sh"]
    chmod 0755, "claude/hooks/allowlist.sh"
    prefix.install "claude"
  end

  service do
    run opt_libexec/"dalejdalej-daemon.sh"
    log_path var/"log/dalejdalej.log"
    error_log_path var/"log/dalejdalej.log"
    run_type :interval
    interval 1800
  end

  def caveats
    <<~EOS
      Config lives at ~/.dalejdalej.yaml (created on first `dalejdalej add`).
      Cloned repos land in ~/dalejdalej/<repo-name>/.

      Start the background daemon:
        brew services start dalejdalej

      Or manage manually:
        dalejdalej start|stop|status|logs
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/dalejdalej 2>&1", 1)
  end
end
