BEGIN;

select _v.register_patch( '013-ooexplr-meta', ARRAY[ '012-sha256-input-uniq' ], NULL );

CREATE TABLE ooexpl_recent_msmt_count AS
SELECT
COUNT(msm_no) as msmt_count,
probe_cc,
probe_asn,
test_name,
test_start_time,
bucket_date
FROM measurement
JOIN report ON report.report_no = measurement.report_no
JOIN autoclaved ON autoclaved.autoclaved_no = report.autoclaved_no
WHERE test_start_time > current_date - interval '31 day'
GROUP BY probe_cc, probe_asn, test_name, test_start_time, bucket_date;

ALTER TABLE ooexpl_recent_msmt_count
ADD PRIMARY KEY(probe_asn, probe_cc, test_name, test_start_time, bucket_date);

CREATE INDEX "ooexpl_recent_msmt_count_probe_cc_idx" ON "public"."ooexpl_bucket_msmt_count"("probe_cc");
CREATE INDEX "ooexpl_recent_msmt_count_test_name_idx" ON "public"."ooexpl_bucket_msmt_count"("test_name");
CREATE INDEX "ooexpl_recent_msmt_count_test_start_time_idx" ON "public"."ooexpl_bucket_msmt_count"("test_start_time");

CREATE TABLE ooexpl_bucket_msmt_count AS
SELECT
COUNT(msm_no) as count,
probe_asn,
probe_cc,
bucket_date
FROM measurement 
JOIN report ON report.report_no = measurement.report_no
JOIN autoclaved ON autoclaved.autoclaved_no = report.autoclaved_no
GROUP BY bucket_date, probe_asn, probe_cc;

ALTER TABLE ooexpl_bucket_msmt_count
ADD PRIMARY KEY(probe_asn, probe_cc, bucket_date);

CREATE TABLE ooexpl_website_msmts AS
SELECT
measurement.msm_no,
input.input,
probe_asn,
probe_cc,
anomaly,
confirmed,
msm_failure as failure,
blocking,
http_experiment_failure,
dns_experiment_failure,
control_failure,
bucket_date
FROM measurement
JOIN input ON input.input_no = measurement.input_no 
JOIN report ON report.report_no = measurement.report_no
JOIN http_verdict ON http_verdict.msm_no = measurement.msm_no
JOIN autoclaved ON autoclaved.autoclaved_no = report.autoclaved_no
WHERE test_name = 'web_connectivity' AND measurement_start_time > current_date - interval '31 day';

UPDATE ooexpl_website_msmts
SET
anomaly = CASE 
	WHEN blocking != 'false' AND blocking != NULL THEN TRUE
	ELSE FALSE
END,
confirmed = FALSE,
failure = CASE
	WHEN control_failure != NULL OR blocking = NULL THEN TRUE
	ELSE FALSE
END;
UPDATE ooexpl_website_msmts SET anomaly = TRUE, confirmed = TRUE WHERE msm_no IN (SELECT msm_no FROM http_request_fp);

CREATE INDEX "ooexpl_website_msmts_anomaly_idx" ON "public"."ooexpl_website_msmts"("anomaly");
CREATE INDEX "ooexpl_website_msmts_confirmed_idx" ON "public"."ooexpl_website_msmts"("confirmed");
CREATE INDEX "ooexpl_website_msmts_failure_idx" ON "public"."ooexpl_website_msmts"("failure");
CREATE INDEX "ooexpl_website_msmts_probe_cc_idx" ON "public"."ooexpl_website_msmts"("probe_cc");
CREATE INDEX "ooexpl_website_msmts_probe_asn_idx" ON "public"."ooexpl_website_msmts"("probe_asn");
CREATE INDEX "ooexpl_website_msmts_input_idx" ON "public"."ooexpl_website_msmts"("input");

COMMIT;
