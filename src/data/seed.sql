-- ═══════════════════════════════════════════════════════════
-- MONIRA — Seed Data
-- Primeira Avenida + Burs iniciais
-- ═══════════════════════════════════════════════════════════

-- Avenidas
INSERT INTO monira_avenues (name, slug, description, color, position) VALUES
('Estilo', 'estilo', 'Roupa, calçado, acessórios, beleza', '#6B21A8', 1),
('Lar', 'lar', 'Decoração, utensílios, mobiliário', '#059669', 2),
('Sabor', 'sabor', 'Comida, bebida, doces, artesanais', '#D97706', 3),
('Tech', 'tech', 'Electrónica, gadgets, acessórios digitais', '#2563EB', 4),
('Serviços', 'servicos', 'Cabeleireiro, costura, reparações, criativo', '#DC2626', 5);

-- Burs iniciais (curadorias editoriais)
INSERT INTO monira_burs (name, slug, description, type, position) VALUES
('Novidades', 'novidades', 'As Ujas e produtos mais recentes na Monira', 'editorial', 1),
('Verificados', 'verificados', 'Moradores verificados com reputação confirmada', 'editorial', 2),
('Feito Cá', 'feito-ca', 'Produtos criados e produzidos localmente', 'editorial', 3);
