CREATE DATABASE if NOT EXISTS itinere;
USE itinere;

CREATE TABLE if NOT EXISTS tipo_manutenzione(
	id INT PRIMARY KEY,
	descrizione VARCHAR(255),
	costo INT
);

CREATE TABLE if NOT EXISTS squadra(
	id INT PRIMARY KEY,
	manutenzione INT,
	FOREIGN KEY(manutenzione) REFERENCES tipo_manutenzione(id)
);

CREATE TABLE if NOT EXISTS operaio(
	cf CHAR(16) PRIMARY KEY,
	nome VARCHAR(255),
	cognome VARCHAR(255),
	datanascita DATE,
	luogonascita VARCHAR(255),
	indirizzo VARCHAR(255),
	telefono CHAR(13),
	squadra INT,
	FOREIGN KEY(squadra) REFERENCES squadra(id)
);

CREATE TABLE if NOT EXISTS autostrada(
	id INT PRIMARY KEY,
	nome VARCHAR(255)
);

CREATE TABLE if NOT EXISTS intervento(
	id INT PRIMARY KEY,
	autostrada INT,
	squadra INT,
	DATA DATE,
	FOREIGN KEY(autostrada) REFERENCES autostrada(id),
	FOREIGN KEY(squadra) REFERENCES squadra(id)
);

CREATE TABLE if NOT EXISTS pianificazione(
	id INT PRIMARY KEY,
	autostrada INT,
	manutenzione INT,
	DATA DATE,
	FOREIGN KEY(autostrada) REFERENCES autostrada(id),
	FOREIGN KEY(manutenzione) REFERENCES tipo_manutenzione(id)
);

-- 2
delimiter //
CREATE PROCEDURE if NOT EXISTS op2(IN autostrada VARCHAR(255))
BEGIN
	SELECT o.*
	FROM operaio o
	JOIN squadra s ON o.squadra = s.id
	JOIN intervento i ON s.id = i.squadra
	JOIN autostrada a ON i.autostrada = a.id
	WHERE a.nome = autostrada;
END //
delimiter ;
CALL op2('A1');

-- 3
DROP PROCEDURE if EXISTS op3;
delimiter //
CREATE PROCEDURE if NOT EXISTS op3(IN autostrada VARCHAR(255), IN anno YEAR)
BEGIN
	SELECT COUNT(i.id) AS num_interventi
	FROM intervento i
	WHERE i.autostrada = autostrada AND year(i.`DATA`) = anno
	GROUP BY i.id;
END //
delimiter ;
CALL op3('A1', 2022);

-- 4
delimiter //
CREATE PROCEDURE if NOT EXISTS op4(IN anno YEAR)
BEGIN
	SELECT a.*
	FROM autostrada a 
	WHERE a.id NOT IN (
								SELECT i.autostrada
								FROM intervento i
								WHERE YEAR(i.data) = anno
							);
END //
delimiter ;
CALL op4(2022);

-- 5
DROP PROCEDURE if EXISTS op5;
delimiter //
CREATE PROCEDURE if NOT EXISTS op5(IN mese INT, IN anno YEAR)
BEGIN
	DROP TEMPORARY TABLE if EXISTS temp;
	CREATE TEMPORARY TABLE temp(
		id INT PRIMARY KEY,
		manutenzione INT,
		num_interventi INT
	);
	
	INSERT INTO temp
	SELECT s.id, s.manutenzione, COUNT(i.id) AS numInter
	FROM squadra s
	JOIN intervento i ON s.id = i.squadra
	WHERE MONTH(i.`DATA`) = mese AND YEAR(i.`DATA`) = anno
	GROUP BY i.id
	HAVING numInter >= ALL(SELECT COUNT(*)
								  FROM intervento i1
								  WHERE MONTH(i1.`DATA`) = mese AND YEAR(i1.`DATA`) = anno
								  GROUP BY i.id
								 );
END //
delimiter ;
CALL op5(02, 2022);
SELECT * FROM temp;

-- 6
DROP PROCEDURE if EXISTS op6;
delimiter //
CREATE PROCEDURE if NOT EXISTS op6(IN x_input INT)
BEGIN
	SELECT a.*
	FROM autostrada a
	JOIN intervento i ON a.id = i.autostrada
	WHERE i.`DATA` = DATE_ADD(CURRENT_DATE(), INTERVAL x_input DAY);
END //
delimiter ;
CALL op6(10);

-- 7
DROP PROCEDURE if EXISTS op7;
delimiter //
CREATE PROCEDURE if NOT EXISTS op7(IN soglia INT)
BEGIN
	SELECT a.*, SUM(t.costo) AS costo_tot
	FROM autostrada a
	JOIN pianificazione p ON a.id = p.autostrada
	JOIN tipo_manutenzione t ON p.manutenzione = t.id
	GROUP BY t.costo
	HAVING costo_tot > soglia AND costo_tot >= ALL(
																 	SELECT t1.costo
																 	FROM tipo_manutenzione t1
																 	JOIN pianificazione p1 ON t1.id = p1.manutenzione
																 );
END //
delimiter ;
CALL op7(1000);

-- 8
DROP VIEW if EXISTS num_interventi;
CREATE VIEW if NOT EXISTS num_interventi AS
	SELECT a.id, COUNT(i.id) AS numInterventi
	FROM autostrada a
	JOIN intervento i ON a.id = i.autostrada
	GROUP BY a.id;
SELECT * FROM num_interventi;

DROP PROCEDURE if EXISTS op8;
delimiter //
CREATE PROCEDURE if NOT EXISTS op8(IN manutenzione INT, data_pianificazione DATE, anno YEAR)
BEGIN
	if(SELECT * FROM autostrada a JOIN num_interventi n ON a.id = n.id HAVING n.numInterventi) <= ALL (SELECT * FROM num_interventi) then
		INSERT INTO pianificazione p VALUES(NEW.id, p.autostrada, manutenzione, DATA);
	END if;
END //

-- 9
DROP TRIGGER if EXISTS t9;
delimiter //
CREATE TRIGGER if NOT EXISTS t9
AFTER INSERT ON pianificazione
FOR EACH ROW
BEGIN
	if NOT EXISTS(SELECT * FROM intervento i WHERE i.autostrada = NEW.autostrada AND month(i.`DATA`) = MONTH(NEW.data)) then
		INSERT INTO pianificazione VALUES(NEW.id, NEW.autostrada, NEW.manutenzione, CURRENT_DATE());
	ELSE
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Messaggio';
	END if;
END //