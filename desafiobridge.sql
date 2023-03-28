CREATE TABLE IF NOT EXISTS tbpedidos (
	pedcodigo int NOT NULL,
	pedcliente varchar(255) NOT NULL,
	pedata date NOT NULL DEFAULT NOW(),
	pedendereco varchar(255) NOT NULL,
	pedpreco decimal(14, 2) NOT NULL DEFAULT 0,
	CONSTRAINT pk_tbpedidos PRIMARY KEY (pedcodigo)
);

CREATE TABLE IF NOT EXISTS tbprodutos (
	procodigo int NOT NULL,
	pronome varchar(255) NOT NULL,
	prodescricao varchar(255) NOT NULL,
	propreco decimal(14, 2) NOT NULL,
	pedcodigo int,
	CONSTRAINT pk_tbprodutos PRIMARY KEY (procodigo),
	CONSTRAINT fk_tbprodutos_tbpedidos FOREIGN KEY (pedcodigo) REFERENCES tbpedidos(pedcodigo)
);

CREATE TABLE IF NOT EXISTS tbcategorias (
	catcodigo int NOT NULL,
	catnome varchar(255) NOT NULL,
	catnumprodutos int DEFAULT 0,
	CONSTRAINT pk_tbcategorias PRIMARY KEY (catcodigo)
);

CREATE TABLE IF NOT EXISTS tbcategoriaproduto (
	capcodigo int NOT NULL,
	catcodigo int NOT NULL,
	procodigo int NOT NULL,
	CONSTRAINT pk_tbcategoriaproduto PRIMARY KEY (capcodigo),
	CONSTRAINT fk_tbcategoriaproduto_tbcategorias FOREIGN KEY (catcodigo) REFERENCES tbcategorias(catcodigo),
	CONSTRAINT fk_tbcategoriaproduto_tbprodutos FOREIGN KEY (procodigo) REFERENCES tbprodutos(procodigo)
);

CREATE TABLE IF NOT EXISTS tbpedidoproduto (
	pepcodigo int NOT NULL,
	pedcodigo int NOT NULL,
	procodigo int NOT NULL UNIQUE,
	CONSTRAINT pk_tbpedidoproduto PRIMARY KEY (pepcodigo),
	CONSTRAINT fk_tbpedidoproduto_tbpedidos FOREIGN KEY (pedcodigo) REFERENCES tbpedidos(pedcodigo),
	CONSTRAINT fk_tbpedidoproduto_tbprodutos FOREIGN KEY (procodigo) REFERENCES tbprodutos(procodigo)
);

----------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_preco_pedido_insert() RETURNS TRIGGER
AS
$$
DECLARE
	preco decimal;
BEGIN
	UPDATE tbprodutos SET pedcodigo = new.pedcodigo WHERE procodigo = new.procodigo;
	SELECT SUM(propreco) FROM tbprodutos WHERE pedcodigo = new.pedcodigo INTO preco;
	UPDATE tbpedidos SET pedpreco = preco WHERE pedcodigo = new.pedcodigo;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_preco_pedido_del() RETURNS TRIGGER
AS
$$
DECLARE
	preco decimal;
BEGIN
	UPDATE tbprodutos SET pedcodigo = null WHERE procodigo = old.procodigo;
	SELECT SUM(propreco) FROM tbprodutos WHERE pedcodigo = old.pedcodigo INTO preco;
	IF preco THEN
		UPDATE tbpedidos SET pedpreco = preco WHERE pedcodigo = old.pedcodigo;
	ELSE
		UPDATE tbpedidos SET pedpreco = 0 WHERE pedcodigo = old.pedcodigo;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE or replace TRIGGER altera_preco_pedido_insert
AFTER INSERT ON tbpedidoproduto
FOR EACH ROW
EXECUTE PROCEDURE set_preco_pedido_insert();

CREATE or replace TRIGGER altera_preco_pedido_del
before delete ON tbpedidoproduto
FOR EACH ROW
EXECUTE PROCEDURE set_preco_pedido_del();

----------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_numprodutos_categorias_insert() RETURNS TRIGGER
AS
$$
DECLARE
	numprodutos int;
BEGIN
	SELECT catnumprodutos FROM tbcategorias WHERE catcodigo = new.catcodigo INTO numprodutos;
	UPDATE tbcategorias SET catnumprodutos = numprodutos + 1 WHERE catcodigo = new.catcodigo;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_numprodutos_categorias_del() RETURNS TRIGGER
AS
$$
DECLARE
	numprodutos int;
BEGIN
	SELECT catnumprodutos FROM tbcategorias WHERE catcodigo = old.catcodigo INTO numprodutos;
	UPDATE tbcategorias SET catnumprodutos = numprodutos - 1 WHERE catcodigo = old.catcodigo;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE or replace TRIGGER altera_numprodutos_categorias_insert
AFTER INSERT ON tbcategoriaproduto
FOR EACH ROW
EXECUTE PROCEDURE set_numprodutos_categorias_insert();

CREATE or replace TRIGGER altera_numprodutos_categorias_del
before delete ON tbcategoriaproduto
FOR EACH ROW
EXECUTE PROCEDURE set_numprodutos_categorias_del();

----------------------------------------------------------------------------------------------------

INSERT INTO tbpedidos (pedcodigo, pedcliente, pedata, pedendereco)
SELECT
	generate_series(1, 50) ,
	'Cliente ' || generate_series(1,50),
	NOW() - (random() * '365 days'::interval),
	'Endereço ' || generate_series(1,50)
FROM generate_series(1, 1);

INSERT INTO tbprodutos (procodigo, pronome, prodescricao, propreco)
SELECT
	generate_series(1, 50) ,
	'Produto ' || generate_series(1,50),
	'Descrição ' || generate_series(1,50),
	(random() * 100)::numeric(10, 2)
FROM generate_series(1, 1);

INSERT INTO tbpedidoproduto (pepcodigo, pedcodigo, procodigo)
SELECT
	generate_series(1, 50),
	generate_series(1, 50),
	generate_series(1, 50)
FROM generate_series(1, 1);

INSERT INTO tbcategorias (catcodigo, catnome)
	SELECT
	generate_series(1, 50),
	'Categoria ' || generate_series(1,50)
FROM generate_series(1, 1);

INSERT INTO tbcategoriaproduto (capcodigo, catcodigo, procodigo)
SELECT
	generate_series(1, 50),
	generate_series(1, 50),
	generate_series(1, 50)
FROM generate_series(1, 1);

INSERT INTO tbprodutos (procodigo, pronome, prodescricao, propreco)
VALUES (51, 'Produto 1', 'Descricao 1', (random() * 100)::numeric(10, 2));

----------------------------------------------------------------------------------------------------

--Listar todos os produtos com nome, descrição e preço em ordem alfabética crescente;
SELECT * FROM tbprodutos ORDER BY pronome ASC;

--Listar todas as categorias com nome e número de produtos associados, em ordem alfabética crescente;
SELECT * FROM tbcategorias ORDER BY catnome ASC;

--Listar todos os pedidos com data, endereço de entrega e total do pedido (soma dos preços dos itens),
--em ordem decrescente de data;
SELECT * FROM tbpedidos ORDER BY pedata DESC;

--Listar todos os produtos que já foram vendidos em pelo menos um pedido, com
--nome, descrição, preço e quantidade total vendida, em ordem decrescente de quantidade total vendida;
SELECT t.procodigo, t.pronome, t.prodescricao, t.propreco, count(t2.procodigo) AS quantidade_vendida
FROM tbprodutos t 
INNER JOIN tbpedidoproduto t2 ON t.procodigo = t2.procodigo 
GROUP BY t.procodigo 
HAVING count(t2.procodigo) > 0
ORDER BY quantidade_vendida DESC;

--Listar todos os pedidos feitos por um determinado cliente, filtrando-os por um determinado período, 
--em ordem alfabética crescente do nome do cliente e ordem crescente da data do pedido;
SELECT * FROM tbpedidos WHERE pedcliente <> 'Cliente 1' AND pedata > '2022-04-17' ORDER BY pedcliente ASC, pedata DESC;

--Listar possíveis produtos com nome replicado e a quantidade de replicações,
--em ordem decrescente de quantidade de replicações;
SELECT pronome, COUNT(*) - 1 AS replicacoes
FROM tbprodutos
GROUP BY pronome
HAVING COUNT(*) > 1
ORDER BY replicacoes DESC;

--drop table tbpedidoproduto;
--drop table tbcategoriaproduto ;
--drop table tbcategorias ;
--drop table tbprodutos ;
--drop table tbpedidos ;