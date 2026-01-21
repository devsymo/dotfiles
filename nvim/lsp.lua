return {
    'neovim/nvim-lspconfig',
    dependencies = {
        'williamboman/mason.nvim',
        'hrsh7th/nvim-cmp',
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
        'saadparwaiz1/cmp_luasnip',
        'L3MON4D3/LuaSnip',
        'rafamadriz/friendly-snippets',
    },
    config = function()
        -- 1. UI & Diagnostics
        vim.diagnostic.config({
            virtual_text = true,
            severity_sort = true,
            float = {
                style = 'minimal',
                border = 'rounded',
                source = 'if_many',
                header = '',
                prefix = '',
            },
            signs = {
                text = {
                    [vim.diagnostic.severity.ERROR] = '✘',
                    [vim.diagnostic.severity.WARN]  = '▲',
                    [vim.diagnostic.severity.HINT]  = '⚑',
                    [vim.diagnostic.severity.INFO]  = '»',
                },
            },
        })

        -- Globally Rounded Borders for Hover/Signature
        local orig = vim.lsp.util.open_floating_preview
        ---@diagnostic disable-next-line: duplicate-set-field
        function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
            opts = opts or {}
            opts.border = opts.border or 'rounded'
            return orig(contents, syntax, opts, ...)
        end

        -- 2. LspAttach: Keymaps, Highlighting, and Autoformat
        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('user.lsp_attach', { clear = true }),
            callback = function(args)
                local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
                local buf = args.buf
                local map = function(mode, lhs, rhs) vim.keymap.set(mode, lhs, rhs, { buffer = buf }) end

                -- Standard LSP Maps
                map('n', 'K', vim.lsp.buf.hover)
                map('n', 'gd', vim.lsp.buf.definition)
                map('n', 'gi', vim.lsp.buf.implementation)
                map('n', 'gr', vim.lsp.buf.references)
                map('n', 'gl', vim.diagnostic.open_float)
                map('n', '<F2>', vim.lsp.buf.rename)
                map('n', '<leader>ca', vim.lsp.buf.code_action)
                map({ 'n', 'x' }, '<F3>', function() vim.lsp.buf.format({ async = true }) end)

                -- Symbol Highlighting
                if client:supports_method('textDocument/documentHighlight') then
                    local group = vim.api.nvim_create_augroup('user.lsp_highlight', { clear = false })
                    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                        buffer = buf, group = group, callback = vim.lsp.buf.document_highlight,
                    })
                    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                        buffer = buf, group = group, callback = vim.lsp.buf.clear_references,
                    })
                end

                -- Autoformatting (Filtered by filetype)
                local autoformat_filetypes = { lua = true, go = true, typescript = true }
                if autoformat_filetypes[vim.bo[buf].filetype] and client:supports_method('textDocument/formatting') then
                    vim.api.nvim_create_autocmd('BufWritePre', {
                        buffer = buf,
                        callback = function()
                            vim.lsp.buf.format({ bufnr = buf, id = client.id, timeout_ms = 1000 })
                        end,
                    })
                end
            end,
        })

        -- 3. Server Configuration (The modern vim.lsp.config pattern)
        local caps = require('cmp_nvim_lsp').default_capabilities()

        -- Define Server Configs
        local servers = {
            lua_ls = {
                cmd = { 'lua-language-server' },
                settings = { Lua = { diagnostics = { globals = { 'vim' } }, workspace = { checkThirdParty = false } } }
            },
            gopls = {
                cmd = { 'gopls' },
                settings = { gopls = { staticcheck = true, completeUnimported = true } }
            },
            intelephense = { cmd = { 'intelephense', '--stdio' } },
            ts_ls = { cmd = { 'typescript-language-server', '--stdio' } },
            eslint = { cmd = { 'vscode-eslint-language-server', '--stdio' } },
        }

        -- Apply and Enable
        for name, config in pairs(servers) do
            config.capabilities = caps
            vim.lsp.config[name] = config
            vim.lsp.enable(name)
        end

        -- 4. Completion (nvim-cmp)
        local cmp = require('cmp')
        local luasnip = require('luasnip')
        require('luasnip.loaders.from_vscode').lazy_load()

        cmp.setup({
            snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
            mapping = cmp.mapping.preset.insert({
                ['<CR>'] = cmp.mapping.confirm({ select = false }),
                ['<Tab>'] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_next_item()
                    elseif luasnip.expand_or_jumpable() then
                        luasnip.expand_or_jump()
                    else
                        fallback()
                    end
                end, { 'i', 's' }),
                ['<S-Tab>'] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_prev_item()
                    elseif luasnip.jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end, { 'i', 's' }),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
                { name = 'path' },
            }, {
                { name = 'buffer' },
            }),
            window = { documentation = cmp.config.window.bordered() },
        })

        require('mason').setup()
    end
}
