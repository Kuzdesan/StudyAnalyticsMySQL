--TASK1
SELECT 
    CONCAT(SUBSTRING(CONCAT(module_id, ' ', module_name), 1, 16), '...') AS "Модуль",
    CONCAT(SUBSTRING(CONCAT(module_id, '.', lesson_position, ' ', lesson_name), 1, 16), '...') AS "Урок",
    CONCAT(module_id, '.', lesson_position, '.', step_position, ' ', step_name) AS "Шаг"
FROM module INNER JOIN lesson USING (module_id) INNER JOIN step USING (lesson_id)
WHERE step_name LIKE "%_ложенн% запрос%" ORDER BY Модуль, Урок, Шаг;

--TASK2
INSERT INTO step_keyword(step_id, keyword_id) 
SELECT step_id, keyword_id FROM keyword 
CROSS JOIN step 
WHERE REGEXP_INSTR(step_name, CONCAT('\\b', keyword_name, '\\b')) 
ORDER BY step_id;

--TASK3
SELECT CONCAT(module_id, '.', lesson_position, '.', 
              IF(step_position<10, CONCAT(0,step_position), step_position), ' ', step_name) AS "Шаг" 
FROM module 
    INNER JOIN lesson USING(module_id)
    INNER JOIN step USING(lesson_id)
    INNER JOIN step_keyword USING(step_id)
    INNER JOIN keyword USING(keyword_id)
    
WHERE 
keyword_name LIKE "MAX" 
OR 
keyword_name LIKE "AVG"
GROUP BY Шаг 
HAVING COUNT(keyword_name)=2 
ORDER BY Шаг;

--TASK4
SELECT Gr AS Группа,  
            CASE
                WHEN rate <= 10 THEN "от 0 до 10"
                WHEN rate <= 15 THEN "от 11 до 15"
                WHEN rate <= 27 THEN "от 16 до 27"
                ELSE "больше 27"
            END AS Интервал, 
COUNT(sn) AS Количество
FROM
    (SELECT sn, rate, 
                    CASE
                        WHEN rate <=10 THEN "I"
                        WHEN rate <=15 THEN "II"
                        WHEN rate <=27 THEN "III"
                        ELSE "IV"
                    END 
    AS Gr FROM
        (SELECT sn, COUNT(*) AS rate FROM 
            (SELECT DISTINCT student_name AS sn, step_id AS si
                FROM student INNER JOIN step_student USING (student_id)
                    WHERE result = "correct") AS query1
        GROUP BY sn ORDER BY rate) AS query2) 
AS query3
GROUP BY Группа, Интервал;

--TASK5
WITH get_count_correct (st_n_c, count_correct) 
  AS (
    SELECT step_name, count(*)
    FROM 
        step 
        INNER JOIN step_student USING (step_id)
    WHERE result = "correct"
    GROUP BY step_name
   ),
  get_count_wrong (st_n_w, count_wrong) 
  AS (
    SELECT step_name, count(*)
    FROM 
        step 
        INNER JOIN step_student USING (step_id)
    WHERE result = "wrong"
    GROUP BY step_name
   )  
SELECT st_n_c AS Шаг,
                    CASE 
                        WHEN st_n_w IS NULL THEN 100
                        ELSE ROUND(count_correct / (count_correct + count_wrong) * 100)
                    END
                        
    AS Успешность
FROM  
    get_count_correct 
    LEFT JOIN get_count_wrong ON st_n_c = st_n_w 
UNION
SELECT st_n_w AS Шаг,
                    CASE 
                        WHEN st_n_c IS NULL THEN 0
                        ELSE ROUND(count_correct / (count_correct + count_wrong) * 100)
                    END
    AS Успешность
FROM  
    get_count_correct 
    RIGHT JOIN get_count_wrong ON st_n_c = st_n_w
ORDER BY 2,1;

--TASK6
SET @all_steps := (SELECT COUNT(DISTINCT step_id) FROM step_student);

WITH qr1(student_name, steps)
    AS (
        SELECT student_name, COUNT(DISTINCT step_id) AS steps
        FROM student INNER JOIN step_student USING(student_id)
        WHERE result="correct"
        GROUP BY student_name ORDER BY steps)
        
SELECT 
    student_name AS Студент, 
    (ROUND((steps/@all_steps)*100)) AS Прогресс,
        CASE
            WHEN (ROUND((steps/@all_steps)*100))=100 THEN 'Сертификат с отличием'
            WHEN (ROUND((steps/@all_steps)*100))>=80 THEN 'Сертификат'
            ELSE ''
        END AS Результат 
FROM qr1 ORDER BY Прогресс DESC, student_name;

--TASK7
SELECT 
    student_name AS "Студент",
    CONCAT(SUBSTRING(step_name, 1, 20), '...') AS "Шаг",
    result AS "Результат",
    FROM_UNIXTIME(submission_time) AS "Дата_отправки",
    SEC_TO_TIME(
        IFNULL(
                   submission_time-(LAG(submission_time) OVER (ORDER BY submission_time)), 0
        )
    ) AS "Разница"
FROM step INNER JOIN step_student USING(step_id) INNER JOIN student USING(student_id)
WHERE student_name='student_61';

--TASK8
WITH t1(Урок, Среднее_время) AS
    (SELECT
        CONCAT(module_id, '.', lesson_position, ' ', lesson_name) AS "Урок",
        ROUND(((AVG(time_per_lesson))/(3600)), 2) AS "Среднее_время"
    FROM
        (SELECT module_id,
            lesson_position,
            lesson_name,
            student_id,
            SUM(time_per_step) AS "time_per_lesson"
        FROM
                (SELECT
                    module_id,
                    lesson_position,
                    lesson_name,
                    SUBSTRING(step_name,1, 15) AS step_name,
                    student_id,
                    SUM(submission_time-attempt_time) AS time_per_step
                FROM module
                    INNER JOIN lesson USING(module_id)
                    INNER JOIN step USING(lesson_id)
                    INNER JOIN step_student USING(step_id)
                WHERE (submission_time-attempt_time)<=14400
                GROUP BY step_name, student_id, module_id,lesson_position, lesson_name
                ORDER BY student_id) AS query
        GROUP BY student_id, module_id,lesson_position, lesson_name) AS query2
    GROUP BY module_id,lesson_position, lesson_name
    ORDER BY Среднее_время)
SELECT
ROW_NUMBER() OVER (ORDER BY Среднее_время) AS Номер,
Урок,
Среднее_время
FROM t1;

--TASK9
WITH info(Модуль, Студент, Пройдено_шагов) AS  
        (SELECT module_id AS "Модуль", student_name AS "Студент", COUNT(DISTINCT step_id) AS "Пройдено_шагов"
            FROM module INNER JOIN lesson USING(module_id)
                        INNER JOIN step USING(lesson_id)
                        INNER JOIN step_student USING(step_id)
                        INNER JOIN student USING(student_id)
            WHERE result="correct"
            GROUP BY Модуль, Студент
            ORDER BY Модуль, Студент)
SELECT 
    Модуль, 
    Студент, 
    Пройдено_шагов,
    ROUND((Пройдено_шагов/
    (MAX(Пройдено_шагов) OVER (PARTITION BY Модуль)))*100, 1) AS "Относительный_рейтинг"
FROM info
ORDER BY Модуль, Относительный_рейтинг DESC, Студент;

--TASK10
WITH t1(Студент, Урок, step_id, ptr_time) AS
    (SELECT 
    student_name AS Студент, 
    CONCAT(module_id, '.', lesson_position)  AS Урок,
    step_id,
    submission_time
    FROM module 
        INNER JOIN lesson USING(module_id)
        INNER JOIN step USING(lesson_id)
        INNER JOIN step_student USING(step_id)
        INNER JOIN student USING(student_id)
    WHERE result = "correct" AND student_name IN 
              (SELECT DISTINCT student_name FROM 
                (SELECT module_id, lesson_position, student_name, 
                        COUNT(lesson_position) OVER (PARTITION BY student_name) AS "num"
                 FROM module 
                        INNER JOIN lesson USING(module_id)
                        INNER JOIN step USING(lesson_id)
                        INNER JOIN step_student USING(step_id)
                        INNER JOIN student USING(student_id)
                 WHERE result = "correct"
                 GROUP BY module_id, lesson_position, student_name) AS query 
               WHERE num>=3))
SELECT 
    qq.Студент, 
    qq.Урок, 
    FROM_UNIXTIME(qq.Макс_время_отправки) AS Макс_время_отправки,
    IFNULL(CEIL((qq.Макс_время_отправки - LAG(qq.Макс_время_отправки, 1) OVER(PARTITION BY Студент ORDER BY           qq.Макс_время_отправки)) / 86400), '-') AS Интервал
FROM 
(WITH t1(Студент, Урок, step_id, ptr_time) AS
    (SELECT 
    student_name AS Студент, 
    CONCAT(module_id, '.', lesson_position)  AS Урок,
    step_id,
    submission_time
    FROM module 
        INNER JOIN lesson USING(module_id)
        INNER JOIN step USING(lesson_id)
        INNER JOIN step_student USING(step_id)
        INNER JOIN student USING(student_id)
    WHERE result = "correct" AND student_name IN 
              (SELECT DISTINCT student_name FROM 
                (SELECT module_id, lesson_position, student_name, 
                        COUNT(lesson_position) OVER (PARTITION BY student_name) AS "num"
                 FROM module 
                        INNER JOIN lesson USING(module_id)
                        INNER JOIN step USING(lesson_id)
                        INNER JOIN step_student USING(step_id)
                        INNER JOIN student USING(student_id)
                 WHERE result = "correct"
                 GROUP BY module_id, lesson_position, student_name) AS query 
               WHERE num>=3))
SELECT 
q.Студент, q.Урок, q.Макс_время_отправки
FROM 
(
    WITH t1(Студент, Урок, step_id, ptr_time) AS
    (SELECT 
    student_name AS Студент, 
    CONCAT(module_id, '.', lesson_position)  AS Урок,
    step_id,
    submission_time
    FROM module 
        INNER JOIN lesson USING(module_id)
        INNER JOIN step USING(lesson_id)
        INNER JOIN step_student USING(step_id)
        INNER JOIN student USING(student_id)
    WHERE result = "correct" AND student_name IN 
              (SELECT DISTINCT student_name FROM 
                (SELECT module_id, lesson_position, student_name, 
                        COUNT(lesson_position) OVER (PARTITION BY student_name) AS "num"
                 FROM module 
                        INNER JOIN lesson USING(module_id)
                        INNER JOIN step USING(lesson_id)
                        INNER JOIN step_student USING(step_id)
                        INNER JOIN student USING(student_id)
                 WHERE result = "correct"
                 GROUP BY module_id, lesson_position, student_name) AS query 
               WHERE num>=3))
    
SELECT 
    Студент, 
    Урок, 
    MAX(ptr_time) OVER (PARTITION BY Студент, Урок) AS Макс_время_отправки
    FROM t1
    )
AS q
 GROUP BY 1,2,3) AS qq
ORDER BY 1, 3;

--TASK11
SET @avg_difference := (SELECT ROUND(AVG(submission_time-attempt_time))
                       FROM step INNER JOIN step_student USING(step_id) INNER JOIN student USING(student_id)
                       WHERE student_name = "student_59" AND (submission_time-attempt_time)<=3600);
                       
WITH t1(stn, step_id, sub, st, difference, res) AS                  
    (SELECT 
        student_name AS stn,
        step_id,
        submission_time AS sub,
        CONCAT(module_id, '.', lesson_position, '.', step_position) AS st,
        IF((submission_time-attempt_time)<=3600, (submission_time-attempt_time), @avg_difference) AS difference,
        result AS res
    FROM module 
        INNER JOIN lesson USING(module_id) 
        INNER JOIN step USING (lesson_id) 
        INNER JOIN step_student USING(step_id)
        INNER JOIN student USING(student_id)
    WHERE student_name = "student_59")
SELECT 
    stn AS Студент,
    st AS Шаг,
    ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY sub) AS Номер_попытки,
    res AS Результат,
    SEC_TO_TIME(difference) AS Время_попытки,
    ROUND((difference/(SUM(difference) OVER (PARTITION BY st)))*100, 2) AS Относительное_время
FROM t1
ORDER BY step_id, Номер_попытки;

--TASK12
SELECT Группа, Студент, Количество_шагов FROM 
((SELECT 
    "I" AS Группа,
    student_name AS Студент,
    COUNT(*) AS Количество_шагов
FROM 
    (SELECT 
         student_name,
         step_id,
         COUNT(*) AS "Количество_шагов1" 
     FROM 
        (WITH gr1(stn, stid, subt, res) AS
            (SELECT 
                 student_name,
                 step_id,
                 submission_time,
                 result
            FROM student
                 INNER JOIN step_student USING(student_id)
                 INNER JOIN step USING(step_id)
            ORDER BY student_name, submission_time) 
        SELECT 
         stid AS step_id,
         stn AS student_name, 
         res,
         LAG(res) OVER 
             (PARTITION BY stn, stid ORDER BY subt) AS prev_res
        FROM gr1)
     AS query1
     WHERE prev_res = "correct" AND res="wrong"
     GROUP BY step_id, student_name)
AS query
GROUP BY Группа, Студент)

UNION

(SELECT 
    "II" AS Группа,
    student_name AS Студент,
    COUNT(sum_res) AS Количество_шагов
FROM
    (SELECT 
         student_name,
         step_id,
         COUNT(result) AS sum_res
     FROM student
         INNER JOIN step_student USING(student_id)
         INNER JOIN step USING(step_id)
     WHERE result = "correct" 
     GROUP BY student_name, step_id
     HAVING COUNT(result)>=2) AS query2
GROUP BY Группа, Студент)

UNION

(SELECT 
    "III" AS Группа, 
    student_name AS Студент,
    COUNT(*) AS Количество_шагов
FROM
    (SELECT 
         student_name,
         step_id,
         SUM(result)
    FROM student
         INNER JOIN step_student USING(student_id)
         INNER JOIN step USING(step_id)
    GROUP BY student_name, step_id
    HAVING (SUM(result="correct"))=0) AS query3
GROUP BY Группа, Студент)) AS result_query
ORDER BY Группа,  Количество_шагов DESC, Студент;

