import { BadRequestException, Body, Controller, Delete, Get, Header, HttpCode, Param, ParseUUIDPipe, Patch, Post, Put, UseGuards } from '@nestjs/common';
import { StaffGuard } from '../common/auth';
import {
  CreateCategoryDto,
  CreateItemDto,
  CreateSectionDto,
  ReorderDto,
  UpdateCategoryDto,
  UpdateItemDto,
  UpdateSectionDto,
} from './menu.dto';
import { MenuService } from './menu.service';

@Controller('menu')
export class MenuController {
  constructor(private readonly menu: MenuService) {}

  @Get()
  @Header('Cache-Control', 'public, max-age=60')
  get() {
    return this.menu.publicMenu();
  }
}

@Controller('admin/menu')
@UseGuards(StaffGuard)
export class AdminMenuController {
  constructor(private readonly menu: MenuService) {}

  @Get()
  tree() {
    return this.menu.tree();
  }

  @Post('sections')
  createSection(@Body() dto: CreateSectionDto) {
    return this.menu.createSection(dto);
  }

  @Patch('sections/:id')
  updateSection(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateSectionDto) {
    return this.menu.updateSection(id, dto);
  }

  @Delete('sections/:id')
  @HttpCode(204)
  async deleteSection(@Param('id', ParseUUIDPipe) id: string) {
    await this.menu.deleteSection(id);
  }

  @Post('categories')
  createCategory(@Body() dto: CreateCategoryDto) {
    return this.menu.createCategory(dto);
  }

  @Patch('categories/:id')
  updateCategory(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCategoryDto) {
    return this.menu.updateCategory(id, dto);
  }

  @Delete('categories/:id')
  @HttpCode(204)
  async deleteCategory(@Param('id', ParseUUIDPipe) id: string) {
    await this.menu.deleteCategory(id);
  }

  @Post('items')
  createItem(@Body() dto: CreateItemDto) {
    return this.menu.createItem(dto);
  }

  @Patch('items/:id')
  updateItem(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateItemDto) {
    return this.menu.updateItem(id, dto);
  }

  @Delete('items/:id')
  @HttpCode(204)
  async deleteItem(@Param('id', ParseUUIDPipe) id: string) {
    await this.menu.deleteItem(id);
  }

  @Put('reorder/:kind')
  @HttpCode(204)
  async reorder(@Param('kind') kind: string, @Body() dto: ReorderDto) {
    if (kind !== 'sections' && kind !== 'categories' && kind !== 'items') {
      throw new BadRequestException('kind: sections | categories | items');
    }
    await this.menu.reorder(kind, dto.ids);
  }
}
