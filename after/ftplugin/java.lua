-- jdtls needs a per-project data directory and Eclipse bundles passed on the
-- command line, so it is started here per buffer rather than through
-- vim.lsp.enable() in lua/lsp.lua like the other servers.
--
-- start_or_attach reuses an existing client when the root_dir matches, so
-- opening a second file in the same project does not spawn a second server.
require("java.jdtls").start()
