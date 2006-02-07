/*==============================================================*/
/* Database name:  zeoslib                                      */
/* DBMS name:     ASA                                    */
/* Created on:     09.08.2005 20:27:07                          */
/*==============================================================*/

INSERT INTO date_values VALUES (1, '1000-01-01', '00:00:00', '1000-01-01 00:00:00', '1970-01-01 00:00:00');
INSERT INTO date_values VALUES (2, '2002-12-29', '12:00:00', '2002-12-29 12:00:00', '2002-12-29 12:00:00');
INSERT INTO date_values VALUES (3, '9999-12-31', '23:59:59', '9999-12-31 23:59:59', '9999-12-31 23:59:59');

INSERT INTO number_values VALUES (1,
    -128,-32768,-2147483648, -922337203685477580, -99999.9999,
    -3.3E+38, -3.3E+38, -1.797E+308, '-21474836.48');
INSERT INTO number_values VALUES (2,
	-128,-32768,-2147483648,-922337203685477580, -11111.1111,
	-1.1E-37, -1.1E-37, -2E-308, '-21474836.48');
INSERT INTO number_values VALUES (3, 0, 0, 0, 0, 0, 0, 0, 0, '0');
INSERT INTO number_values VALUES (4, 
	128, 32767, 2147483647, 922337203685477580, 11111.1111,
	3.3E+38, 3.3E+38, 1.797E+308, '21474836.47');
INSERT INTO number_values VALUES (5,
	128, 32767, 147483647, 922337203685477580,  99999.9999,
	1.1E-37, 1.1E-37, 2E-308, '21474836.47');

INSERT INTO string_values VALUES (1,'', '', '', '', NULL, NULL);
INSERT INTO string_values VALUES (2,'Test string', 'Test string',
'Test string', '', NULL, NULL);
INSERT INTO string_values VALUES (3,
'111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111', 
'111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111',
'111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111', 
'111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111', 
NULL, 
NULL);
