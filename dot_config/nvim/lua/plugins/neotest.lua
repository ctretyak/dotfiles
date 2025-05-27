return {
  "nvim-neotest/neotest",
  dependencies = {
    "haydenmeade/neotest-jest", -- Добавляем поддержку Jest
  },
  opts = function(_, opts)
    opts.adapters = opts.adapters or {}

    local function get_jest_config(path)
      -- Определяем корневую директорию пакета (например, через наличие package.json)
      local root = vim.fs.find("package.json", { upward = true, path = path })[1]
      if not root then
        return nil
      end

      -- Ищем jest.config.js в этой директории или возвращаем стандартный
      local config = vim.fs.find("jest.config.js", { path = vim.fn.fnamemodify(root, ":h") })[1]
      return config or "jest.config.js"
    end

    table.insert(
      opts.adapters,
      require("neotest-jest")({
        jestCommand = function(path)
          -- Определяем, какой пакетный менеджер используется
          local root = vim.fs.find("package.json", { upward = true, path = path })[1]
          local package_manager = "npm test --" -- по умолчанию npm
          if vim.fn.filereadable(vim.fn.fnamemodify(root, ":h") .. "/pnpm-lock.yaml") == 1 then
            package_manager = "pnpm test --"
          elseif vim.fn.filereadable(vim.fn.fnamemodify(root, ":h") .. "/yarn.lock") == 1 then
            package_manager = "yarn test --"
          end
          return package_manager
        end,
        jestConfigFile = get_jest_config,
        env = { CI = true },
        cwd = function(path)
          -- Используем корень пакета как рабочую директорию
          local root = vim.fs.find("package.json", { upward = true, path = path })[1]
          return root and vim.fn.fnamemodify(root, ":h") or vim.fn.getcwd()
        end,
      })
    )
  end,
}
