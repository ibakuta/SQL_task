#1 Покажите среднюю зарплату сотрудников за каждый год (средняя заработная плата среди тех, кто работал в отчетный период - статистика с начала до 2005 года).
SELECT distinct YEAR(es.from_date) AS year, ROUND(AVG(es.salary) OVER (PARTITION BY YEAR(es.from_date)),2) AS avg_year_sal
FROM salaries AS es;

#2 Покажите среднюю зарплату сотрудников по каждому отделу. Примечание: принять в расчет только текущие отделы и текущую заработную плату
SELECT distinct de.dept_no, 
		ROUND(AVG(es.salary) OVER (PARTITION BY de.dept_no),2) AS avg_year_sal
FROM salaries AS es
INNER JOIN dept_emp AS de USING (emp_no)
WHERE curdate() BETWEEN de.from_date AND de.to_date AND (curdate() BETWEEN es.from_date AND es.to_date);

#3 Покажите среднюю зарплату сотрудников по каждому отделу за каждый год. Примечание: для средней зарплаты отдела X в году Y нам нужно взять среднее значение всех зарплат в году Y сотрудников, которые были в отделе X в году Y
SELECT distinct de.dept_no, YEAR(es.from_date) AS year,
		ROUND(AVG(es.salary) OVER (PARTITION BY de.dept_no, YEAR(es.from_date)),2) AS avg_year_sal
FROM salaries AS es
INNER JOIN dept_emp AS de USING (emp_no);

#check
SELECT AVG(salary)
FROM salaries AS es
INNER JOIN dept_emp AS de USING (emp_no)
WHERE de.dept_no = 'd001' AND year(es.from_date) = 1985;

#4 Покажите для каждого года самый крупный отдел (по количеству сотрудников) в этом году и его среднюю зарплату
WITH TotCTE (year, dept_no, count_emp, avg_sal, r) AS (
	SELECT year(de.from_date), de.dept_no, COUNT(es.emp_no), AVG(es.salary),
    row_number() over (partition by year(de.from_date) order by COUNT(es.emp_no)desc) AS r
	FROM salaries AS es
	INNER JOIN dept_emp AS de USING (emp_no)
	GROUP BY year(de.from_date), de.dept_no
	ORDER BY year(de.from_date) ASC, COUNT(es.emp_no)desc)

SELECT *
FROM TotCTE
WHERE r =1;

#check 
SELECT YEAR(de.from_date), de.dept_no, COUNT(es.emp_no)
FROM dept_emp  AS de
INNER JOIN salaries AS es USING (emp_no)
WHERE year(de.from_date) = 1990
GROUP BY YEAR(de.from_date), de.dept_no
ORDER BY YEAR(de.from_date) ASC, COUNT(emp_no) DESC;

#5 Покажите подробную информацию о менеджере, который дольше всех исполняет свои обязанности на данный момент
WITH dept_managerCTE (emp_no, dept_no, from_date_manager,work_experience_days ) AS (
	SELECT emp_no, dept_no, from_date, datediff(to_date, from_date) AS work_experience
	FROM dept_manager
	WHERE curdate() BETWEEN from_date AND to_date
	ORDER BY datediff(to_date, from_date) DESC
	LIMIT 1)

SELECT de.emp_no, de.dept_no, CONCAT(ee.first_name, ' ', ee.last_name) AS full_name, 
		ee.birth_date, ee.gender, ee.hire_date, de.from_date_manager, de.work_experience_days
FROM dept_managerCTE AS de
INNER JOIN employees AS ee USING (emp_no);

#6 Покажите топ-10 нынешних сотрудников компании с наибольшей разницей между их зарплатой и текущей средней зарплатой в их отделе.
SELECT distinct es.emp_no, de.dept_no, es.salary,
		ROUND(AVG(es.salary) OVER (PARTITION BY de.dept_no),2) AS avg_year_sal,
        ABS(es.salary - ROUND(AVG(es.salary) OVER (PARTITION BY de.dept_no),2)) AS diff_year_sal
FROM salaries AS es
INNER JOIN dept_emp AS de USING(emp_no)
WHERE curdate() BETWEEN es.from_date AND es.to_date
ORDER BY diff_year_sal DESC
LIMIT 10;

/*7 Из-за кризиса на одно подразделение на своевременную выплату зарплаты выделяется
всего 500 тысяч долларов. Правление решило, что низкооплачиваемые сотрудники
будут первыми получать зарплату. Показать список всех сотрудников, которые будут
вовремя получать зарплату (обратите внимание, что мы должны платить зарплату за
один месяц, но в базе данных мы храним годовые суммы).*/

SELECT d.emp_no, d.salary, d.dept_no, d.total
FROM(
	SELECT es.emp_no, es.salary, de.dept_no, 
		ROUND(sum(salary/12) over (partition by dept_no order by salary
		rows between unbounded preceding and current row),0) as total
		FROM salaries AS es
		INNER JOIN dept_emp AS de USING (emp_no)
		WHERE curdate() BETWEEN es.from_date AND es.to_date
		ORDER BY dept_no, salary) AS d
WHERE d.total <= 500000;

#Дизайн базы данных:
#1. Разработайте базу данных для управления курсами. База данных содержит следующие сущности:
#a. students: student_no, teacher_no, course_no, student_name, email, birth_date.
#В таблице students сделать первичный ключ в сочетании двух полей student_no и birth_date
CREATE TABLE IF NOT EXISTS students (
	student_no INT,
	teacher_no INT NOT NULL,
	course_no INT NOT NULL,
    student_name VARCHAR (20),
    email VARCHAR (30),
	birth_date DATE
) ENGINE = INNODB;


#Секционировать по годам, таблицу students по полю birth_date с помощью механизма range
ALTER TABLE students PARTITION BY RANGE (YEAR(birth_date))
(
 PARTITION p1983 VALUES LESS THAN (1984),
 PARTITION p1984 VALUES LESS THAN (1985),
 PARTITION p1994 VALUES LESS THAN (1995),
 PARTITION p1999 VALUES LESS THAN (2000),
 PARTITION p2000 VALUES LESS THAN (2001),
 PARTITION p2001 VALUES LESS THAN (2002),
 PARTITION p2002 VALUES LESS THAN (2003),
 PARTITION pMAXVALUE VALUES LESS THAN (MAXVALUE)
);

DESC students;

#b. teachers: teacher_no, teacher_name, phone_no
CREATE TABLE IF NOT EXISTS teachers (
	teacher_no INT AUTO_INCREMENT PRIMARY KEY,
    teacher_name VARCHAR (20),
    phone_no INT
) ENGINE = INNODB;

DESC teachers;

#c. courses: course_no, course_name, start_date, end_date
CREATE TABLE IF NOT EXISTS courses (
	course_no INT AUTO_INCREMENT PRIMARY KEY,
    course_name VARCHAR (20),
    start_date DATE,
    end_date DATE
) ENGINE = INNODB;

DESC courses;

#В таблице students сделать первичный ключ в сочетании двух полей student_no и birth_date
ALTER TABLE students ADD CONSTRAINT PRIMARY KEY (student_no, birth_date);

/*ALTER TABLE students ADD CONSTRAINT FOREIGN KEY (teacher_no) REFERENCES teachers (teacher_no)
					ON UPDATE RESTRICT ON DELETE CASCADE;
                    
ALTER TABLE students ADD CONSTRAINT FOREIGN KEY (course_no) REFERENCES courses (course_no)
					ON UPDATE RESTRICT ON DELETE CASCADE;*/

#● Создать индекс по полю students.email
CREATE INDEX students_email ON students (email);

SHOW INDEX FROM employees.students;

# Создать уникальный индекс по полю teachers.phone_no
CREATE UNIQUE INDEX teachers_phone_no ON teachers (phone_no);

#2. На свое усмотрение добавить тестовые данные (7-10 строк) в наши три таблицы.
ALTER TABLE courses MODIFY course_name VARCHAR (40);
INSERT INTO courses (course_no, course_name, start_date, end_date)
VALUES
	 (1, 'Business Intelligence', '2023-01-18', '2023-07-18'),
     (2, 'FrontEnd', '2023-01-31', '2023-08-31'),
     (3, 'Full Stack (JavaScript + Java)', '2023-01-18', '2023-07-18'),
     (4, 'Java', '2023-02-21', '2023-08-21'),
     (5, 'Quality Assurance (QA)', '2023-01-23', '2023-04-23'),
     (6, 'Digital Marketing', '2023-01-03', '2023-06-03'),
     (7, 'UI/UX design', '2023-01-25', '2023-07-25');
     
SELECT *
FROM courses;

ALTER TABLE teachers MODIFY phone_no VARCHAR (14);
INSERT INTO teachers (teacher_no, teacher_name, phone_no)
VALUES
	(1, 'Bob Belcher', 380681234564),
    (2, 'Linda Belcher', 380671234564),
    (3, 'Tina Belcher', 380681234568),
    (4, 'Gene Belcher', 380681237564),
    (5, 'Louise Belcher', 380631234564),
    (6, 'Teddy', 380981234564),
    (7, 'Jimmy Pesto Sr.', 380731234564);

SELECT *
FROM teachers;

INSERT INTO students (student_no, teacher_no, course_no, student_name, email, birth_date)
VALUES
	(1, 7, 1, 'Gial Ackbar', 'qwerty@gmail.com', '1985-10-01'),
    (2, 6, 2, 'Stass Allie', 'qwerty1@gmail.com', '1995-10-01'),
	(3, 5, 3, 'Ponda Baba', 'qwert2y@gmail.com', '1985-11-11'),
    (4, 4, 4, 'Darth Bane', 'qwerty3@gmail.com', '1995-05-01'),
    (5, 3, 5, 'Jar Jar Binks', 'qwerty4@gmail.com', '2000-03-11'),
    (6, 2, 6, 'Tiaan Jerjerrod', 'qwert5y@gmail.com', '2001-07-09'),
    (7, 1, 7, 'Alexsandr Kallus', 'qwerty6@gmail.com', '2005-02-20');

SELECT *
FROM students;

#3. Отобразить данные за любой год из таблицы students и зафиксировать в виду*/
SELECT * FROM students PARTITION (p2001)
WHERE year(birth_date) = 2001;
/*# student_no, teacher_no, course_no, student_name, email, birth_date
'6', '2', '6', 'Tiaan Jerjerrod', 'qwert5y@gmail.com', '2001-07-09'*/

EXPLAIN SELECT * FROM students PARTITION (p2001)
WHERE year(birth_date) = 2001;
/*# id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
'1', 'SIMPLE', 'students', 'p2001', 'ALL', NULL, NULL, NULL, NULL, '1', '100.00', 'Using where'*/

/* #4 Отобразить данные учителя, по любому одному номеру телефона и зафиксировать план
выполнения запроса, где будет видно, что запрос будет выполняться по индексу, а не
методом ALL. */
EXPLAIN SELECT phone_no
FROM teachers;
/*# id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
'1', 'SIMPLE', 'teachers', NULL, 'index', NULL, 'teachers_phone_no', '59', NULL, '7', '100.00', 'Using index'*/

/*Далее индекс из поля teachers.phone_no сделать невидимым и
зафиксировать план выполнения запроса, где ожидаемый результат - метод ALL.*/
ALTER TABLE teachers 
ALTER INDEX teachers_phone_no INVISIBLE;

EXPLAIN SELECT phone_no
FROM teachers;
/*# id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
'1', 'SIMPLE', 'teachers', NULL, 'ALL', NULL, NULL, NULL, NULL, '7', '100.00', NULL*/

 /*В итоге индекс оставить в статусе - видимый*/
ALTER TABLE teachers ALTER INDEX teachers_phone_no VISIBLE; 

EXPLAIN SELECT phone_no
FROM teachers;
/*# id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
'1', 'SIMPLE', 'teachers', NULL, 'index', NULL, 'teachers_phone_no', '59', NULL, '7', '100.00', 'Using index'*/

#5 Специально сделаем 3 дубляжа в таблице students (добавим еще 3 одинаковые строки).
INSERT INTO students (student_no, teacher_no, course_no, student_name, email, birth_date)
VALUES
    (8, 3, 5, 'Jar Jar Binks', 'qwerty4@gmail.com', '2000-03-11'),
    (9, 2, 6, 'Tiaan Jerjerrod', 'qwert5y@gmail.com', '2001-07-09'),
    (10, 1, 7, 'Alexsandr Kallus', 'qwerty6@gmail.com', '2005-02-20');

#6. Написать запрос, который выводит строки с дубляжами.
WITH doubleCTE (student_no, teacher_no, course_no, student_name, email, birth_date,r) AS (
	SELECT *
	FROM (
		SELECT student_no, teacher_no, course_no, student_name, email, birth_date,
		ROW_NUMBER() OVER (PARTITION BY student_name) AS r
		FROM students
		) AS T
	WHERE r > 1)

SELECT cte.student_no, cte.teacher_no, cte.course_no, cte.student_name, cte.birth_date, cte.email
FROM doubleCTE AS cte
INNER JOIN students AS s USING(birth_date);








