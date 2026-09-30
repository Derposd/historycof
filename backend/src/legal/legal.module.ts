import { Controller, Get, Header, Module, NotFoundException, Param } from '@nestjs/common';
import { VenueModule } from '../venue/venue.controller';
import { VenueService } from '../venue/venue.service';
import { LEGAL_TITLES, LEGAL_VERSION, LegalDocKind, legalHtml, renderLegal } from './documents';

const KINDS = Object.keys(LEGAL_TITLES) as LegalDocKind[];

/**
 * Документы для гостей: политика, согласие на обработку ПДн, согласие на рекламу,
 * правила бонусной программы. /legal/:kind — для приложения, /legal/:kind/page —
 * HTML-страница для ссылки в RuStore / Google Play / App Store.
 */
@Controller('legal')
export class LegalController {
  constructor(private readonly venue: VenueService) {}

  private kind(raw: string): LegalDocKind {
    if (!KINDS.includes(raw as LegalDocKind)) throw new NotFoundException('Документ не найден');
    return raw as LegalDocKind;
  }

  @Get()
  list() {
    return { version: LEGAL_VERSION, documents: KINDS.map((k) => ({ kind: k, title: LEGAL_TITLES[k] })) };
  }

  @Get(':kind')
  @Header('Cache-Control', 'public, max-age=300')
  async doc(@Param('kind') raw: string) {
    const kind = this.kind(raw);
    return { kind, version: LEGAL_VERSION, title: LEGAL_TITLES[kind], markdown: renderLegal(kind, await this.venue.get()) };
  }

  @Get(':kind/page')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=300')
  async page(@Param('kind') raw: string) {
    const kind = this.kind(raw);
    return legalHtml(renderLegal(kind, await this.venue.get()), LEGAL_TITLES[kind]);
  }
}

@Module({ imports: [VenueModule], controllers: [LegalController] })
export class LegalModule {}
