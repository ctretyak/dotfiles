-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
if vim.g.vscode then
    local vscode = require("vscode")

    local map = function(mode, lhs, cmd, desc)
        vim.keymap.set(mode, lhs, function()
            vscode.call(cmd)
        end, {
            desc = desc,
            silent = true
        })
    end

    map("n", "<leader>cf", "editor.action.formatDocument", "Format Document (VSCode)")
    map("n", "<leader>cr", "editor.action.rename", "Rename Symbol (VSCode)")
    map("n", "<leader>ca", "editor.action.quickFix", "Quick Fix (VSCode)")
    map("n", "<leader>co", "editor.action.organizeImports", "Organize Imports (VSCode)")

    map("n", "gi", "editor.action.goToImplementation", "Go to Implementation (VSCode)")
    map("n", "gr", "editor.action.referenceSearch.trigger", "Find References (VSCode)")

    map("n", "<leader>bd", "workbench.action.closeActiveEditor", "Close Editor (VSCode)")
    map("n", "<leader>bo", "workbench.action.closeOtherEditors", "Close Other Editors (VSCode)")
    map("n", "<leader>br", "workbench.action.closeEditorsToTheRight", "Close Editors to the Right (VSCode)")
    map("n", "<leader>bl", "workbench.action.closeEditorsToTheLeft", "Close Editors to the Left (VSCode)")

    map("n", "[d", "editor.action.marker.prev", "Previous Diagnostic (VSCode)")
    map("n", "]d", "editor.action.marker.next", "Next Diagnostic (VSCode)")
    map("n", "[e", "editor.action.marker.prevInFiles", "Previous Error (VSCode)")
    map("n", "]e", "editor.action.marker.nextInFiles", "Next Error (VSCode)")

    map("n", "<leader>ft", "workbench.action.terminal.toggleTerminal", "Toggle Terminal")

    map("n", "<leader>gb", "gitlens.toggleFileBlame", "Git Blame (GitLens)")

    map("n", "<leader>uz", "workbench.action.toggleZenMode", "Toggle Zen Mode")
    map("n", "<leader>wm", "workbench.action.toggleCenteredLayout", "Toggle Centered Layout")

    map("i", "<C-k>", "editor.action.triggerParameterHints", "Signature Help")

    map("n", "<leader>,", "workbench.action.showAllEditors", "Show Buffers")
    map("n", "<leader>fb", "workbench.action.showAllEditors", "Show Buffers")

    map("n", "<leader>sk", "workbench.action.openGlobalKeybindings", "Show Keybindings")

    map({"n", "x"}, "<leader>sw", "workbench.action.findInFiles", "Find Next Match")

    map({"n", "v"}, "<leader>aa", "workbench.panel.chat.view.copilot.focus", "Toggle Copilot Chat")

    map("n", "<leader>gg", "workbench.view.scm", "Open Source Control")
    -- map("n", "<leader>gg", "gitlens.showHomeView", "Open GitLens")

    map("n", "<leader>e", "workbench.files.action.focusFilesExplorer", "Toggle Sidebar")
end

