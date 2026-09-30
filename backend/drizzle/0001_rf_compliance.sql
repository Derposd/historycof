CREATE TYPE "public"."consent_kind" AS ENUM('pd', 'marketing');--> statement-breakpoint
CREATE TABLE "consents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guest_id" uuid NOT NULL,
	"kind" "consent_kind" NOT NULL,
	"version" text NOT NULL,
	"granted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone,
	"ip" text,
	"user_agent" text
);
--> statement-breakpoint
ALTER TABLE "guests" ALTER COLUMN "push_news_enabled" SET DEFAULT false;--> statement-breakpoint
ALTER TABLE "menu_items" ADD COLUMN "nutrition" jsonb;--> statement-breakpoint
ALTER TABLE "menu_items" ADD COLUMN "allergens" text;--> statement-breakpoint
ALTER TABLE "consents" ADD CONSTRAINT "consents_guest_id_guests_id_fk" FOREIGN KEY ("guest_id") REFERENCES "public"."guests"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "consents_guest_kind_idx" ON "consents" USING btree ("guest_id","kind");--> statement-breakpoint
-- Раньше подписка на новости включалась по умолчанию, без отдельного согласия на рекламу
-- (38-ФЗ, ст. 18) — такие подписки недействительны, выключаем их все.
UPDATE "guests" SET "push_news_enabled" = false;
