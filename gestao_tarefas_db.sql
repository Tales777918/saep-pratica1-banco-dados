CREATE TABLE colaboradores (
    id_colaborador SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha VARCHAR(100) NOT NULL,
    cargo VARCHAR(80) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE,
    descricao VARCHAR(255)
);

CREATE TABLE tarefas (
    id_tarefa SERIAL PRIMARY KEY,
    titulo VARCHAR(120) NOT NULL,
    descricao TEXT,
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_entrega DATE NOT NULL,
    prioridade VARCHAR(20) NOT NULL DEFAULT 'Média',
    status VARCHAR(30) NOT NULL DEFAULT 'Pendente',
    id_colaborador INT NOT NULL,
    id_categoria INT NOT NULL,
    CONSTRAINT fk_tarefa_colaborador FOREIGN KEY (id_colaborador)
        REFERENCES colaboradores (id_colaborador) ON DELETE RESTRICT,
    CONSTRAINT fk_tarefa_categoria FOREIGN KEY (id_categoria)
        REFERENCES categorias (id_categoria) ON DELETE RESTRICT,
    CONSTRAINT chk_prioridade CHECK (prioridade IN ('Baixa', 'Média', 'Alta', 'Urgente')),
    CONSTRAINT chk_status CHECK (status IN ('Pendente', 'Em Andamento', 'Concluída', 'Atrasada', 'Cancelada'))
);

CREATE TABLE historico_tarefas (
    id_historico SERIAL PRIMARY KEY,
    id_tarefa INT NOT NULL,
    id_colaborador INT NOT NULL,
    acao_realizada VARCHAR(255) NOT NULL,
    data_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historico_tarefa FOREIGN KEY (id_tarefa)
        REFERENCES tarefas (id_tarefa) ON DELETE CASCADE,
    CONSTRAINT fk_historico_colaborador FOREIGN KEY (id_colaborador)
        REFERENCES colaboradores (id_colaborador) ON DELETE RESTRICT
);

CREATE OR REPLACE FUNCTION fn_validar_tarefa_antes_inserir()
RETURNS TRIGGER AS $$
DECLARE
    v_ativo BOOLEAN;
BEGIN
    SELECT ativo INTO v_ativo
    FROM colaboradores
    WHERE id_colaborador = NEW.id_colaborador;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Erro de Integridade: Colaborador ID % não encontrado.', NEW.id_colaborador;
    END IF;

    IF v_ativo IS FALSE THEN
        RAISE EXCEPTION 'Regra de Negócio Violada: Não é permitido atribuir tarefas a um colaborador inativo (ID %).', NEW.id_colaborador;
    END IF;

    NEW.data_criacao := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_tarefa
BEFORE INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tarefa_antes_inserir();

CREATE OR REPLACE FUNCTION fn_registrar_log_tarefa()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO historico_tarefas (id_tarefa, id_colaborador, acao_realizada, data_registro)
    VALUES (
        NEW.id_tarefa,
        NEW.id_colaborador,
        'Tarefa criada e atribuída com status inicial: ' || NEW.status,
        NEW.data_criacao
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_criacao_tarefa
AFTER INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_log_tarefa();

CREATE OR REPLACE FUNCTION fn_buscar_colaboradores(p_termo_busca TEXT)
RETURNS TABLE (
    id_colaborador INT,
    nome VARCHAR,
    email VARCHAR,
    cargo VARCHAR,
    ativo BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id_colaborador,
        c.nome,
        c.email,
        c.cargo,
        c.ativo
    FROM colaboradores c
    WHERE c.nome ILIKE '%' || p_termo_busca || '%'
       OR c.email ILIKE '%' || p_termo_busca || '%'
    ORDER BY c.nome ASC;
END;
$$ LANGUAGE plpgsql;

INSERT INTO colaboradores (nome, email, senha, cargo, ativo) VALUES
('Ana Paula Silva', 'ana.silva@consultoria.com.br', 'senha123', 'Gerente de Projetos', TRUE),
('Carlos Eduardo Mendes', 'carlos.mendes@consultoria.com.br', 'dev2026!', 'Analista de Sistemas', TRUE),
('Mariana Costa', 'mariana.costa@consultoria.com.br', 'mari@998', 'Consultora Financeira', TRUE),
('Roberto Almeida', 'roberto.almeida@consultoria.com.br', 'rob12345', 'Consultor Externo', FALSE);

INSERT INTO categorias (nome, descricao) VALUES
('Desenvolvimento', 'Tarefas relacionadas à codificação, banco de dados e infraestrutura'),
('Consultoria Estratégica', 'Levantamento de requisitos, reuniões com clientes e diagnósticos'),
('Financeiro e Compliance', 'Auditoria de contratos, faturamento e prestação de contas');

INSERT INTO tarefas (titulo, descricao, data_entrega, prioridade, status, id_colaborador, id_categoria) VALUES
('Modelagem do Banco SAEP', 'Criar DER e scripts DDL/DML no PostgreSQL', CURRENT_DATE + INTERVAL '2 days', 'Urgente', 'Em Andamento', 2, 1),
('Apresentação de Escopo Cliente X', 'Reunião de alinhamento de cronograma executivo', CURRENT_DATE + INTERVAL '5 days', 'Alta', 'Pendente', 1, 2),
('Fechamento Trimestral de Projetos', 'Revisar horas alocadas e faturamento', CURRENT_DATE + INTERVAL '10 days', 'Média', 'Pendente', 3, 3),
('Migração de Servidor Legado', 'Backup e validação de integridade', CURRENT_DATE - INTERVAL '1 day', 'Urgente', 'Atrasada', 2, 1);

INSERT INTO historico_tarefas (id_tarefa, id_colaborador, acao_realizada) VALUES
(1, 2, 'Status atualizado de Pendente para Em Andamento');

CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT 
    c.nome AS colaborador,
    t.titulo AS tarefa,
    cat.nome AS categoria,
    t.data_entrega AS prazo_entrega,
    t.status
FROM tarefas t
INNER JOIN colaboradores c ON t.id_colaborador = c.id_colaborador
INNER JOIN categorias cat ON t.id_categoria = cat.id_categoria;

CREATE OR REPLACE VIEW vw_cronograma_prazos AS
SELECT 
    t.id_tarefa,
    t.titulo AS tarefa,
    t.data_entrega AS prazo_final,
    (t.data_entrega - CURRENT_DATE) AS dias_restantes,
    t.status,
    c.nome AS responsavel
FROM tarefas t
INNER JOIN colaboradores c ON t.id_colaborador = c.id_colaborador
ORDER BY t.data_entrega ASC;