# AI Models Used in CardMaestro

This document specifies the AI models used throughout the CardMaestro application.

## OpenAI Models

### Text Generation
- **Model**: `gpt-5-mini`
- **Usage**: Card content generation, back-side text creation, card suggestions
- **Service**: GPT5MiniService.swift
- **Note**: This is a newer model (2025) that provides cost-effective text generation and suggestion generation

### Image Generation
- **Model**: `gpt-image-1` 
- **Usage**: Deck icon generation, card images
- **Service**: DeckIconGenerationService.swift
- **Note**: This is a newer model (2025) that supersedes DALL-E 3 for image generation

## Anthropic Models

**Note**: Claude API support has been removed. All text generation now uses GPT-5-mini.

## Apple Intelligence

### Text Generation
- **Usage**: On-device card content generation (iOS 18.4+)
- **Service**: AppleIntelligenceTextService.swift

### Image Generation
- **Usage**: On-device image generation using Apple Image Playground
- **Service**: BackgroundImageGenerationService.swift
- **Note**: Uses professional animal prompts (e.g., "raccoon chef", "elephant scientist")

## Important Notes

1. **Do not revert to older models**: 
   - Use `gpt-image-1` instead of `dall-e-3`
   - Use `gpt-5-mini` instead of `gpt-4` or older models

2. **Error Handling**: All API failures should be silent (console logging only) rather than showing user alerts

3. **Image Prompts**: Use professional animals instead of people in image generation prompts for better results with Apple Image Playground