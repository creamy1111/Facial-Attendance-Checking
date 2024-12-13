CREATE TABLE "STUDENT" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"student_id" VARCHAR(255) NOT NULL,
	"student_name" VARCHAR(255) NOT NULL,
	"date_of_birth" DATE NOT NULL,
	"class_id" INTEGER NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "CLASS" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"class_name" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "SUBJECT" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"subject_name" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "FACE" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"student_id" INTEGER NOT NULL,
	"url" TEXT NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "ATTENDANCE_RECORD" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"student_id" INTEGER NOT NULL,
	"class_id" INTEGER NOT NULL,
	"subject_id" INTEGER NOT NULL,
	"date" DATE NOT NULL,
	"status" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "ATTENDANCE_SUMMARY" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"class_id" INTEGER NOT NULL,
	"subject_id" INTEGER NOT NULL,
	"student_id" INTEGER NOT NULL,
	"total_absent" VARCHAR(255) NOT NULL,
	"total_present" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "SUBJECT_CLASS" (
	"class_id, subject_id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"class_id" INTEGER NOT NULL,
	"subject_id" INTEGER NOT NULL,
	PRIMARY KEY("class_id, subject_id")
);


ALTER TABLE "ATTENDANCE_RECORD"
ADD FOREIGN KEY("student_id") REFERENCES "STUDENT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_RECORD"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_RECORD"
ADD FOREIGN KEY("subject_id") REFERENCES "SUBJECT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "FACE"
ADD FOREIGN KEY("student_id") REFERENCES "STUDENT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_SUMMARY"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_SUMMARY"
ADD FOREIGN KEY("subject_id") REFERENCES "SUBJECT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_SUMMARY"
ADD FOREIGN KEY("student_id") REFERENCES "STUDENT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "SUBJECT_CLASS"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "SUBJECT_CLASS"
ADD FOREIGN KEY("subject_id") REFERENCES "SUBJECT"("id")
	ON UPDATE NO ACTION ON DELETE NO ACTION;
	ALTER TABLE "STUDENT"
	ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
	ON UPDATE NO ACTION ON DELETE NO ACTION;

CREATE OR REPLACE FUNCTION create_attendance_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO "ATTENDANCE_SUMMARY" (class_id, subject_id, student_id, total_absent, total_present)
    SELECT NEW.class_id, s.id, NEW.id, '0', '0'
    FROM "SUBJECT" s;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_attendance_summary
AFTER INSERT ON "STUDENT"
FOR EACH ROW
EXECUTE FUNCTION create_attendance_summary();

CREATE OR REPLACE FUNCTION create_empty_attendance_record()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO "ATTENDANCE_RECORD" (student_id, class_id, subject_id, date, status)
    SELECT DISTINCT ON (ar.date) NEW.id, NEW.class_id, sc.subject_id, ar.date, ''
    FROM "SUBJECT_CLASS" sc
    JOIN "ATTENDANCE_RECORD" ar ON ar.class_id = NEW.class_id AND ar.subject_id = sc.subject_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM "ATTENDANCE_RECORD"
        WHERE student_id = NEW.id AND class_id = NEW.class_id AND subject_id = sc.subject_id AND date = ar.date
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_empty_attendance_record
AFTER INSERT ON "STUDENT"
FOR EACH ROW
EXECUTE FUNCTION create_empty_attendance_record();

CREATE OR REPLACE FUNCTION update_attendance_summary()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.status = 'Present') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_present = GREATEST(total_present::INTEGER + 1, 0)
            WHERE student_id = NEW.student_id AND class_id = NEW.class_id AND subject_id = NEW.subject_id;
        ELSIF (NEW.status = 'Absent') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_absent = GREATEST(total_absent::INTEGER + 1, 0)
            WHERE student_id = NEW.student_id AND class_id = NEW.class_id AND subject_id = NEW.subject_id;
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.status = 'Present') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_present = GREATEST(total_present::INTEGER - 1, 0)
            WHERE student_id = OLD.student_id AND class_id = OLD.class_id AND subject_id = OLD.subject_id;
        ELSIF (OLD.status = 'Absent') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_absent = GREATEST(total_absent::INTEGER - 1, 0)
            WHERE student_id = OLD.student_id AND class_id = OLD.class_id AND subject_id = OLD.subject_id;
        END IF;
        IF (NEW.status = 'Present') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_present = GREATEST(total_present::INTEGER + 1, 0)
            WHERE student_id = NEW.student_id AND class_id = NEW.class_id AND subject_id = NEW.subject_id;
        ELSIF (NEW.status = 'Absent') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_absent = GREATEST(total_absent::INTEGER + 1, 0)
            WHERE student_id = NEW.student_id AND class_id = NEW.class_id AND subject_id = NEW.subject_id;
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        IF (OLD.status = 'Present') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_present = GREATEST(total_present::INTEGER - 1, 0)
            WHERE student_id = OLD.student_id AND class_id = OLD.class_id AND subject_id = OLD.subject_id;
        ELSIF (OLD.status = 'Absent') THEN
            UPDATE "ATTENDANCE_SUMMARY"
            SET total_absent = GREATEST(total_absent::INTEGER - 1, 0)
            WHERE student_id = OLD.student_id AND class_id = OLD.class_id AND subject_id = OLD.subject_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_attendance_summary
AFTER INSERT OR UPDATE OR DELETE ON "ATTENDANCE_RECORD"
FOR EACH ROW
EXECUTE FUNCTION update_attendance_summary();

CREATE OR REPLACE FUNCTION add_default_absent_record()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO "ATTENDANCE_RECORD" (student_id, class_id, subject_id, date, status)
    SELECT s.id, sc.class_id, sc.subject_id, NEW.date, 'Absent'
    FROM "STUDENT" s
    JOIN "SUBJECT_CLASS" sc ON sc.class_id = s.class_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM "ATTENDANCE_RECORD"
        WHERE student_id = s.id AND class_id = sc.class_id AND subject_id = sc.subject_id AND date = NEW.date
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_add_default_absent_record
AFTER INSERT ON "ATTENDANCE_RECORD"
FOR EACH ROW
EXECUTE FUNCTION add_default_absent_record();

CREATE OR REPLACE FUNCTION create_attendance_summary_for_new_subject_class()
RETURNS TRIGGER AS $$
BEGIN
    -- Chèn một bản tóm tắt điểm danh cho từng học sinh trong lớp và môn học mới
    INSERT INTO "ATTENDANCE_SUMMARY" (class_id, subject_id, student_id, total_absent, total_present)
    SELECT 
        NEW.class_id, 
        NEW.subject_id, 
        s.id, 
        '0', -- Tổng số vắng mặt ban đầu
        '0'  -- Tổng số có mặt ban đầu
    FROM "STUDENT" s
    WHERE s.class_id = NEW.class_id; -- Lọc học sinh theo lớp học mới
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_attendance_summary_for_subject_class
AFTER INSERT ON "SUBJECT_CLASS"
FOR EACH ROW
EXECUTE FUNCTION create_attendance_summary_for_new_subject_class();

CREATE OR REPLACE FUNCTION update_and_delete_duplicate_record()
RETURNS TRIGGER AS $$
BEGIN
    -- Kiểm tra nếu có bản ghi cũ trùng với bản ghi mới
    IF EXISTS (
        SELECT 1
        FROM "ATTENDANCE_RECORD"
        WHERE student_id = NEW.student_id
          AND class_id = NEW.class_id
          AND subject_id = NEW.subject_id
          AND date = NEW.date
    ) THEN
        -- Cập nhật trạng thái của bản ghi cũ bằng trạng thái của bản ghi mới
        UPDATE "ATTENDANCE_RECORD"
        SET status = NEW.status
        WHERE student_id = NEW.student_id
          AND class_id = NEW.class_id
          AND subject_id = NEW.subject_id
          AND date = NEW.date;

        -- Xóa bản ghi mới để tránh trùng lặp
        RETURN NULL;
    ELSE
        -- Nếu không có bản ghi cũ, chèn bản ghi mới
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_and_delete_duplicate
BEFORE INSERT ON "ATTENDANCE_RECORD"
FOR EACH ROW
EXECUTE FUNCTION update_and_delete_duplicate_record();

INSERT INTO "CLASS" ("class_name") VALUES
('ICT Class 1');

INSERT INTO "STUDENT" ("student_id", "student_name", "date_of_birth", "class_id") VALUES
('BA12-068', 'Nguyen Dinh Hai', '2003-05-26', '1'),
('BA12-003', 'Tran Ngoc Viet Anh', '2003-03-14', '1'),
('BA12-006', 'Ngo Huyen Anh', '2003-12-24', '1'),
('BA12-007', 'Tang Van Anh', '2003-09-01', '1'),
('BA12-093', 'Luyen Pham Ngoc Khanh', '2003-04-04', '1'),
('BA12-095', 'Pham Duc Khiem', '2003-02-09', '1');

INSERT INTO "SUBJECT" ("subject_name") VALUES
('Advance Databases');

-- INSERT INTO "ATTENDANCE_RECORD" (
--     class_id,
--     subject_id,
--     student_id,
--     date,
--     status
-- )	
-- VALUES
--     ('1', '1', '1', '2024-12-13', 'Present'),
-- 	('1', '1', '2', '2024-12-13', 'Present'),
--     ('1', '1', '3', '2024-12-13', 'Present'),
--     ('1', '1', '4', '2024-12-13', 'Present'),
-- 	('1', '1', '5', '2024-12-13', 'Present'),
-- 	('1', '1', '6', '2024-12-13', 'Present');
